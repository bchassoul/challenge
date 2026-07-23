defmodule Challenge.Jobs.OrderJobTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.OrderJob

  import Challenge.Jobs.TestSupport,
    only: [challenge_sample_payload: 0, dependency_violations: 1, names: 1]

  test "valid payload returns ordered tasks end to end without HTTP" do
    assert {:ok, ordered_tasks} = OrderJob.call(challenge_sample_payload())

    assert names(ordered_tasks) == ["task-1", "task-3", "task-2", "task-4"]
    assert dependency_violations(ordered_tasks) == []
  end

  test "invalid payload errors pass through without trying to build or sort a graph" do
    assert {:error,
            %Error{
              code: "duplicate_task_name",
              details: %{
                "name" => "task-1",
                "path" => "$.tasks[1].name",
                "first_path" => "$.tasks[0].name"
              }
            }} =
             OrderJob.call(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo first"},
                 %{"name" => "task-1", "command" => "echo second", "requires" => ["task-1"]}
               ]
             })
  end

  test "cycle errors pass through as dependency_cycle" do
    assert {:error,
            %Error{
              code: "dependency_cycle",
              details: %{"remaining_tasks" => ["task-1", "task-2"]}
            }} =
             OrderJob.call(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo one", "requires" => ["task-2"]},
                 %{"name" => "task-2", "command" => "echo two", "requires" => ["task-1"]}
               ]
             })
  end

  test "domain API does not expose HTTP statuses or content negotiation" do
    assert {:error, %Error{} = error} = OrderJob.call(%{"tasks" => "not-a-list"})

    refute Map.has_key?(Map.from_struct(error), :status)
    refute Map.has_key?(Map.from_struct(error), :conn)
    refute Map.has_key?(Map.from_struct(error), :accept)
    refute Map.has_key?(Map.from_struct(error), :response_format)
  end
end
