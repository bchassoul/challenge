defmodule Challenge.Jobs.DomainTypesTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task

  test "error can be built with stable code, message, and default empty details" do
    assert Error.new("invalid_payload", "Invalid request payload") == %Error{
             code: "invalid_payload",
             message: "Invalid request payload",
             details: %{}
           }
  end

  test "error can carry useful details" do
    assert Error.new("unknown_dependency", "Unknown dependency", %{
             "task" => "task-2",
             "dependency" => "task-1"
           }) == %Error{
             code: "unknown_dependency",
             message: "Unknown dependency",
             details: %{"task" => "task-2", "dependency" => "task-1"}
           }
  end

  test "task carries only domain task data" do
    task = %Task{name: "task-1", command: "touch /tmp/file1", requires: []}

    assert struct_keys(task) == MapSet.new([:command, :name, :requires])
  end

  test "task defaults requires to an empty list" do
    assert %Task{name: "task-1", command: "touch /tmp/file1"}.requires == []
  end

  test "job carries only domain job data" do
    job = %Job{
      tasks: [
        %Task{name: "task-1", command: "touch /tmp/file1"},
        %Task{name: "task-2", command: "cat /tmp/file1", requires: ["task-1"]}
      ]
    }

    assert struct_keys(job) == MapSet.new([:tasks])
  end

  test "domain errors do not carry HTTP response data" do
    error = Error.new("dependency_cycle", "Dependency cycle detected")

    assert struct_keys(error) == MapSet.new([:code, :details, :message])
  end

  defp struct_keys(struct) do
    struct
    |> Map.from_struct()
    |> Map.keys()
    |> MapSet.new()
  end
end
