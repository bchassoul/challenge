defmodule ChallengeWeb.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias ChallengeWeb.Router

  @opts Router.init([])

  test "returns a JSON 404 error envelope for an unknown path" do
    conn =
      :get
      |> conn("/missing")
      |> Router.call(@opts)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    assert decoded_body(conn) == %{
             "error" => %{
               "code" => "not_found",
               "message" => "The requested resource was not found.",
               "details" => %{}
             }
           }
  end

  test "returns a JSON 404 error envelope for unsupported /jobs methods" do
    for method <- [:get, :put, :delete] do
      conn =
        method
        |> conn("/jobs")
        |> Router.call(@opts)

      assert conn.status == 404
      assert content_type(conn) == "application/json"
      assert decoded_body(conn)["error"]["code"] == "not_found"
    end
  end

  test "POST /jobs reaches the controller placeholder" do
    conn =
      :post
      |> conn("/jobs", ~s({"tasks":[]}))
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 501
    assert content_type(conn) == "application/json"
    assert decoded_body(conn)["error"]["code"] == "not_implemented"
  end

  defp content_type(conn) do
    conn
    |> get_resp_header("content-type")
    |> List.first()
    |> String.split(";")
    |> List.first()
  end

  defp decoded_body(conn) do
    JSON.decode!(conn.resp_body)
  end
end
