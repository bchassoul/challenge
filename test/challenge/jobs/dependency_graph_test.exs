defmodule Challenge.Jobs.DependencyGraphTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.DependencyGraph
  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task

  import Challenge.Jobs.TestSupport, only: [task: 1, task: 2]

  test "empty job builds empty graph maps" do
    assert DependencyGraph.build(%Job{tasks: []}) == %DependencyGraph{
             task_by_name: %{},
             in_degree: %{},
             dependents: %{},
             input_index: %{}
           }
  end

  test "independent tasks have zero in-degree and no dependents" do
    task_1 = task("task-1")
    task_2 = task("task-2")

    graph = DependencyGraph.build(%Job{tasks: [task_1, task_2]})

    assert graph.task_by_name == %{"task-1" => task_1, "task-2" => task_2}
    assert graph.in_degree == %{"task-1" => 0, "task-2" => 0}
    assert graph.dependents == %{"task-1" => [], "task-2" => []}
  end

  test "chain dependencies produce correct in-degree and dependent links" do
    task_1 = task("task-1")
    task_2 = task("task-2", ["task-1"])
    task_3 = task("task-3", ["task-2"])

    graph = DependencyGraph.build(%Job{tasks: [task_1, task_2, task_3]})

    assert graph.in_degree == %{"task-1" => 0, "task-2" => 1, "task-3" => 1}
    assert graph.dependents == %{
             "task-1" => ["task-2"],
             "task-2" => ["task-3"],
             "task-3" => []
           }
  end

  test "branch dependencies produce correct in-degree for tasks with multiple requirements" do
    task_1 = task("task-1")
    task_2 = task("task-2")
    task_3 = task("task-3", ["task-1", "task-2"])

    graph = DependencyGraph.build(%Job{tasks: [task_1, task_2, task_3]})

    assert graph.in_degree == %{"task-1" => 0, "task-2" => 0, "task-3" => 2}
    assert graph.dependents == %{
             "task-1" => ["task-3"],
             "task-2" => ["task-3"],
             "task-3" => []
           }
  end

  test "shared dependencies produce one required task with multiple dependents" do
    task_1 = task("task-1")
    task_2 = task("task-2", ["task-1"])
    task_3 = task("task-3", ["task-1"])

    graph = DependencyGraph.build(%Job{tasks: [task_1, task_2, task_3]})

    assert graph.in_degree == %{"task-1" => 0, "task-2" => 1, "task-3" => 1}
    assert graph.dependents == %{
             "task-1" => ["task-2", "task-3"],
             "task-2" => [],
             "task-3" => []
           }
  end

  test "input_index preserves the original request position for every task" do
    graph =
      DependencyGraph.build(%Job{
        tasks: [
          task("task-c"),
          task("task-a"),
          task("task-b")
        ]
      })

    assert graph.input_index == %{"task-c" => 0, "task-a" => 1, "task-b" => 2}
  end

  test "graph construction assumes validation already checked unknown dependencies" do
    assert_raise KeyError, fn ->
      DependencyGraph.build(%Job{tasks: [task("task-1", ["missing-task"])]})
    end
  end

  test "graph construction assumes validation already checked duplicate task names" do
    first_task = %Task{name: "task-1", command: "echo first"}
    second_task = %Task{name: "task-1", command: "echo second"}

    graph = DependencyGraph.build(%Job{tasks: [first_task, second_task]})

    assert graph.task_by_name == %{"task-1" => second_task}
    assert graph.input_index == %{"task-1" => 1}
  end

end
