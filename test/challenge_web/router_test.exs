defmodule ChallengeWeb.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test
  import Challenge.Jobs.TestSupport, only: [challenge_sample_payload: 0]

  alias ChallengeWeb.Router

  @opts Router.init([])
  @ordered_sample_task_names ["task-1", "task-3", "task-2", "task-4"]

  test "unknown routes and unsupported /jobs methods return JSON 404 errors" do
    for {method, path} <- [
          {:get, "/missing"},
          {:get, "/jobs"},
          {:put, "/jobs"},
          {:delete, "/jobs"}
        ] do
      conn =
        method
        |> conn(path)
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
  end

  test "POST /jobs with application/json returns expected ordered JSON for the sample" do
    conn =
      challenge_sample_payload()
      |> post_jobs("application/json")

    assert conn.status == 200
    assert content_type(conn) == "application/json"

    assert conn
           |> decoded_body()
           |> task_names() == @ordered_sample_task_names

    assert conn
           |> decoded_body()
           |> Map.fetch!("tasks")
           |> Enum.all?(&(MapSet.new(Map.keys(&1)) == MapSet.new(["command", "name"])))
  end

  test "POST /jobs with text/x-shellscript returns expected bash script for the sample" do
    conn =
      challenge_sample_payload()
      |> post_jobs("text/x-shellscript")

    assert conn.status == 200
    assert content_type(conn) == "text/x-shellscript"

    assert conn.resp_body ==
             "#!/usr/bin/env bash\n" <>
               "touch /tmp/file1\n" <>
               "echo 'Hello World!' > /tmp/file1\n" <>
               "cat /tmp/file1\n" <>
               "rm /tmp/file1\n"
  end

  test "missing or wildcard Accept defaults to JSON" do
    for accept <- [nil, "*/*"] do
      conn = post_jobs(challenge_sample_payload(), accept)

      assert conn.status == 200
      assert content_type(conn) == "application/json"
      assert decoded_body(conn) |> task_names() == @ordered_sample_task_names
    end
  end

  test "unsupported Accept returns 406 not_acceptable" do
    conn = post_jobs(challenge_sample_payload(), "text/plain")

    assert conn.status == 406
    assert content_type(conn) == "application/json"
    assert decoded_body(conn)["error"]["code"] == "not_acceptable"
  end

  test "malformed JSON returns 400 malformed_json" do
    conn = post_raw_jobs(~s({"tasks":), "application/json")

    assert conn.status == 400
    assert content_type(conn) == "application/json"
    assert decoded_body(conn)["error"]["code"] == "malformed_json"
  end

  test "JSON Content-Type parameters are accepted" do
    conn =
      challenge_sample_payload()
      |> post_jobs("application/json", "application/json; charset=utf-8")

    assert conn.status == 200
    assert content_type(conn) == "application/json"
    assert decoded_body(conn) |> task_names() == @ordered_sample_task_names
  end

  test "unsupported request Content-Type returns 415 unsupported_media_type" do
    for request_content_type <- [nil, "text/plain"] do
      conn = post_jobs(challenge_sample_payload(), "application/json", request_content_type)

      assert conn.status == 415
      assert content_type(conn) == "application/json"
      assert decoded_body(conn)["error"]["code"] == "unsupported_media_type"
    end
  end

  test "oversized request body returns invalid_payload before JSON decoding" do
    conn =
      String.duplicate(" ", 1_000_001)
      |> post_raw_jobs("application/json")

    assert conn.status == 422

    assert decoded_body(conn)["error"] == %{
             "code" => "invalid_payload",
             "message" => "Request body is too large.",
             "details" => %{}
           }
  end

  test "domain errors return 422 with their public error codes" do
    cases = [
      {%{"tasks" => "not-a-list"}, "invalid_payload"},
      {
        %{
          "tasks" => [
            %{"name" => "task-1", "command" => "echo one", "requires" => ["task-2"]},
            %{"name" => "task-2", "command" => "echo two", "requires" => ["task-1"]}
          ]
        },
        "dependency_cycle"
      }
    ]

    for {payload, code} <- cases do
      conn = post_jobs(payload, "application/json")

      assert conn.status == 422
      assert decoded_body(conn)["error"]["code"] == code
    end
  end

  test "error responses do not expose internals" do
    conn =
      post_jobs(
        %{"tasks" => [%{"name" => "task-1", "command" => "echo one", "requires" => [1]}]},
        "application/json"
      )

    body = conn.resp_body

    refute body =~ "Challenge.Jobs"
    refute body =~ "KeyError"
    refute body =~ "in_degree"
    refute body =~ "dependents"
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

  defp task_names(%{"tasks" => tasks}) do
    Enum.map(tasks, & &1["name"])
  end

  defp post_jobs(payload, accept, content_type \\ "application/json") do
    payload
    |> JSON.encode!()
    |> post_raw_jobs(accept, content_type)
  end

  defp post_raw_jobs(body, accept, content_type \\ "application/json") do
    :post
    |> conn("/jobs", body)
    |> put_request_content_type(content_type)
    |> put_accept(accept)
    |> Router.call(@opts)
  end

  defp put_request_content_type(conn, nil), do: conn

  defp put_request_content_type(conn, content_type),
    do: put_req_header(conn, "content-type", content_type)

  defp put_accept(conn, nil), do: conn
  defp put_accept(conn, accept), do: put_req_header(conn, "accept", accept)
end
