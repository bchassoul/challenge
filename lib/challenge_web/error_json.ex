defmodule ChallengeWeb.ErrorJSON do
  @moduledoc false

  import Plug.Conn

  def send_json(conn, status, code, message, details \\ %{}) do
    body =
      JSON.encode!(%{
        "error" => %{
          "code" => code,
          "message" => message,
          "details" => details
        }
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end
end
