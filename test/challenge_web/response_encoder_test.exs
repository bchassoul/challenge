defmodule ChallengeWeb.ResponseEncoderTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias ChallengeWeb.ResponseEncoder

  import Challenge.Jobs.TestSupport, only: [task: 3]

  test "ordered JSON response includes only name and command and handles empty tasks" do
    body =
      [
        task("task-1", "touch /tmp/file1", []),
        task("task-2", "cat /tmp/file1", ["task-1"])
      ]
      |> ResponseEncoder.encode_tasks()
      |> JSON.decode!()

    assert body == %{
             "tasks" => [
               %{"name" => "task-1", "command" => "touch /tmp/file1"},
               %{"name" => "task-2", "command" => "cat /tmp/file1"}
             ]
           }

    refute Map.has_key?(List.first(body["tasks"]), "requires")
    assert ResponseEncoder.encode_tasks([]) |> JSON.decode!() == %{"tasks" => []}
  end

  test "JSON errors use the public envelope with code, message, and details" do
    error =
      Error.new("invalid_payload", "Invalid request payload.", %{
        "path" => "$.tasks"
      })

    assert ResponseEncoder.encode_error(error) |> JSON.decode!() == %{
             "error" => %{
               "code" => "invalid_payload",
               "message" => "Invalid request payload.",
               "details" => %{"path" => "$.tasks"}
             }
           }
  end
end
