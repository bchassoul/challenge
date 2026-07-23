defmodule ChallengeWeb.JobController do
  @moduledoc false

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.OrderJob
  alias Challenge.Jobs.ScriptRenderer
  alias ChallengeWeb.ErrorJSON
  alias ChallengeWeb.ResponseEncoder
  alias ChallengeWeb.ResponseNegotiator

  import Plug.Conn

  @max_body_bytes 1_000_000

  def create(conn) do
    with :ok <- ensure_json_content_type(conn),
         {:ok, response_format} <- ResponseNegotiator.negotiate(conn),
         {:ok, payload, conn} <- decode_json(conn),
         {:ok, ordered_tasks} <- OrderJob.call(payload) do
      send_ordered_tasks(conn, response_format, ordered_tasks)
    else
      {:error, %Error{} = error} ->
        ErrorJSON.send_json(conn, error_status(error), error)

      {:error, %Error{} = error, conn} ->
        ErrorJSON.send_json(conn, error_status(error), error)
    end
  end

  defp ensure_json_content_type(conn) do
    conn
    |> get_req_header("content-type")
    |> case do
      [content_type | _rest] ->
        case Plug.Conn.Utils.content_type(content_type) do
          {:ok, "application", "json", _params} -> :ok
          _other -> unsupported_media_type()
        end

      [] ->
        unsupported_media_type()
    end
  end

  defp decode_json(conn) do
    case read_request_body(conn) do
      {:ok, body, conn} ->
        decode_body(body, conn)

      {:error, :body_too_large, conn} ->
        {:error, Error.new("invalid_payload", "Request body is too large."), conn}

      {:error, _reason, conn} ->
        {:error, Error.new("malformed_json", "Request body is not valid JSON."), conn}
    end
  end

  defp decode_body(body, conn) do
    case JSON.decode(body) do
      {:ok, payload} ->
        {:ok, payload, conn}

      {:error, _reason} ->
        {:error, Error.new("malformed_json", "Request body is not valid JSON."), conn}
    end
  end

  defp read_request_body(conn) do
    read_request_body(conn, [], 0)
  end

  defp read_request_body(conn, chunks, size) do
    case read_body(conn, length: @max_body_bytes, read_length: @max_body_bytes) do
      {:ok, body, conn} ->
        finish_body(conn, [body | chunks], size + byte_size(body))

      {:more, body, conn} ->
        continue_reading_body(conn, [body | chunks], size + byte_size(body))

      {:error, reason} ->
        {:error, reason, conn}
    end
  end

  defp finish_body(conn, chunks, size) do
    if size > @max_body_bytes do
      {:error, :body_too_large, conn}
    else
      body =
        chunks
        |> Enum.reverse()
        |> IO.iodata_to_binary()

      {:ok, body, conn}
    end
  end

  defp continue_reading_body(conn, chunks, size) do
    if size > @max_body_bytes do
      {:error, :body_too_large, conn}
    else
      read_request_body(conn, chunks, size)
    end
  end

  defp send_ordered_tasks(conn, :json, ordered_tasks) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, ResponseEncoder.encode_tasks(ordered_tasks))
  end

  defp send_ordered_tasks(conn, :shell, ordered_tasks) do
    conn
    |> put_resp_content_type("text/x-shellscript")
    |> send_resp(200, ScriptRenderer.render(ordered_tasks))
  end

  defp unsupported_media_type do
    {:error,
     Error.new("unsupported_media_type", "Request Content-Type must be application/json.")}
  end

  defp error_status(%Error{code: "malformed_json"}), do: 400
  defp error_status(%Error{code: "not_acceptable"}), do: 406
  defp error_status(%Error{code: "unsupported_media_type"}), do: 415
  defp error_status(%Error{}), do: 422
end
