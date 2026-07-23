defmodule Challenge.Jobs.ValidatorTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task
  alias Challenge.Jobs.Validator

  test "valid challenge-statement sample becomes a job" do
    assert {:ok,
            %Job{
              tasks: [
                %Task{name: "task-1", command: "touch /tmp/file1", requires: []},
                %Task{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
                %Task{
                  name: "task-3",
                  command: "echo 'Hello World!' > /tmp/file1",
                  requires: ["task-1"]
                },
                %Task{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
              ]
            }} = Validator.validate(sample_payload())
  end

  test "empty tasks list is valid" do
    assert Validator.validate(%{"tasks" => []}) == {:ok, %Job{tasks: []}}
  end

  test "missing task requires becomes an empty list" do
    assert {:ok, %Job{tasks: [%Task{requires: []}]}} =
             Validator.validate(%{"tasks" => [%{"name" => "task-1", "command" => "echo one"}]})
  end

  test "explicit empty task requires stays an empty list" do
    assert {:ok, %Job{tasks: [%Task{requires: []}]}} =
             Validator.validate(%{
               "tasks" => [%{"name" => "task-1", "command" => "echo one", "requires" => []}]
             })
  end

  test "top-level payload must be an object" do
    assert_invalid_payload(Validator.validate([]), "$")
  end

  test "top-level tasks is required" do
    assert_invalid_payload(Validator.validate(%{}), "$.tasks")
  end

  test "top-level tasks must be a list" do
    assert_invalid_payload(Validator.validate(%{"tasks" => "task-1"}), "$.tasks")
  end

  test "unknown top-level fields return invalid_payload" do
    assert {:error,
            %Error{
              code: "invalid_payload",
              details: %{"field" => "unexpected", "path" => "$.unexpected"}
            }} = Validator.validate(%{"tasks" => [], "unexpected" => true})
  end

  test "each task must be an object" do
    assert_invalid_payload(Validator.validate(%{"tasks" => ["task-1"]}), "$.tasks[0]")
  end

  test "task name is required" do
    assert_invalid_payload(
      Validator.validate(%{"tasks" => [%{"command" => "echo one"}]}),
      "$.tasks[0].name"
    )
  end

  test "task name must be a string" do
    assert_invalid_payload(
      Validator.validate(%{"tasks" => [%{"name" => 1, "command" => "echo one"}]}),
      "$.tasks[0].name"
    )
  end

  test "task command is required" do
    assert_invalid_payload(
      Validator.validate(%{"tasks" => [%{"name" => "task-1"}]}),
      "$.tasks[0].command"
    )
  end

  test "task command must be a string" do
    assert_invalid_payload(
      Validator.validate(%{"tasks" => [%{"name" => "task-1", "command" => 1}]}),
      "$.tasks[0].command"
    )
  end

  test "task requires must be a list when present" do
    assert_invalid_payload(
      Validator.validate(%{
        "tasks" => [
          %{"name" => "task-1", "command" => "echo one", "requires" => "task-0"}
        ]
      }),
      "$.tasks[0].requires"
    )
  end

  test "every requires entry must be a string" do
    assert_invalid_payload(
      Validator.validate(%{
        "tasks" => [
          %{"name" => "task-1", "command" => "echo one", "requires" => [1]}
        ]
      }),
      "$.tasks[0].requires[0]"
    )
  end

  test "unknown task fields return invalid_payload" do
    assert {:error,
            %Error{
              code: "invalid_payload",
              details: %{"field" => "extra", "path" => "$.tasks[0].extra"}
            }} =
             Validator.validate(%{
               "tasks" => [%{"name" => "task-1", "command" => "echo one", "extra" => true}]
             })
  end

  test "duplicate task names return duplicate_task_name" do
    assert {:error,
            %Error{
              code: "duplicate_task_name",
              details: %{
                "name" => "task-1",
                "path" => "$.tasks[1].name",
                "first_path" => "$.tasks[0].name"
              }
            }} =
             Validator.validate(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo one"},
                 %{"name" => "task-1", "command" => "echo two"}
               ]
             })
  end

  test "duplicate entries inside one task requires list return duplicate_dependency" do
    assert {:error,
            %Error{
              code: "duplicate_dependency",
              details: %{
                "task" => "task-2",
                "dependency" => "task-1",
                "path" => "$.tasks[1].requires[1]",
                "first_path" => "$.tasks[1].requires[0]"
              }
            }} =
             Validator.validate(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo one"},
                 %{
                   "name" => "task-2",
                   "command" => "echo two",
                   "requires" => ["task-1", "task-1"]
                 }
               ]
             })
  end

  test "dependencies that reference missing task names return unknown_dependency" do
    assert {:error,
            %Error{
              code: "unknown_dependency",
              details: %{
                "task" => "task-1",
                "dependency" => "missing-task",
                "path" => "$.tasks[0].requires[0]"
              }
            }} =
             Validator.validate(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo one", "requires" => ["missing-task"]}
               ]
             })
  end

  test "error details do not expose internal structs" do
    assert {:error, %Error{details: details}} =
             Validator.validate(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo one", "requires" => [1]}
               ]
             })

    refute inspect(details) =~ "Challenge.Jobs"
    refute Map.has_key?(details, "conn")
    refute Map.has_key?(details, "status")
  end

  defp assert_invalid_payload(result, path) do
    assert {:error, %Error{code: "invalid_payload", details: %{"path" => ^path}}} = result
  end

  defp sample_payload do
    %{
      "tasks" => [
        %{
          "name" => "task-1",
          "command" => "touch /tmp/file1"
        },
        %{
          "name" => "task-2",
          "command" => "cat /tmp/file1",
          "requires" => ["task-3"]
        },
        %{
          "name" => "task-3",
          "command" => "echo 'Hello World!' > /tmp/file1",
          "requires" => ["task-1"]
        },
        %{
          "name" => "task-4",
          "command" => "rm /tmp/file1",
          "requires" => ["task-2", "task-3"]
        }
      ]
    }
  end
end
