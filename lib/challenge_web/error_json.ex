defmodule ChallengeWeb.ErrorJSON do
  @moduledoc false

  alias Challenge.Jobs.Error
  alias ChallengeWeb.ResponseEncoder

  import Plug.Conn

  def send_json(conn, status, %Error{} = error) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, ResponseEncoder.encode_error(error))
  end
end
