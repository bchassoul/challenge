defmodule Challenge.Jobs.TopologicalSorterTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.DependencyGraph
  alias Challenge.Jobs.Error
  alias Challenge.Jobs.TopologicalSorter

  import Challenge.Jobs.TestSupport,
    only: [assert_dependencies_before_tasks: 1, job: 1, names: 1, task: 1, task: 2, task: 3]

  test "empty job returns an empty ordered list" do
    assert sort_tasks([]) == {:ok, []}
  end

  test "challenge-statement sample returns the expected deterministic order" do
    tasks = [
      task("task-1", "touch /tmp/file1"),
      task("task-2", "cat /tmp/file1", ["task-3"]),
      task("task-3", "echo 'Hello World!' > /tmp/file1", ["task-1"]),
      task("task-4", "rm /tmp/file1", ["task-2", "task-3"])
    ]

    assert sorted_names(tasks) == {:ok, ["task-1", "task-3", "task-2", "task-4"]}
  end

  test "a simple chain is ordered from root dependency to final dependent" do
    tasks = [
      task("task-3", ["task-2"]),
      task("task-1"),
      task("task-2", ["task-1"])
    ]

    assert sorted_names(tasks) == {:ok, ["task-1", "task-2", "task-3"]}
  end

  test "independent tasks preserve original request order" do
    tasks = [
      task("task-3"),
      task("task-1"),
      task("task-2")
    ]

    assert sorted_names(tasks) == {:ok, ["task-3", "task-1", "task-2"]}
  end

  test "multiple ready tasks preserve original request order" do
    tasks = [
      task("task-1"),
      task("task-2"),
      task("task-3", ["task-1", "task-2"])
    ]

    assert sorted_names(tasks) == {:ok, ["task-1", "task-2", "task-3"]}
  end

  test "a task with multiple dependencies is emitted only after all dependencies are emitted" do
    tasks = [
      task("task-final", ["task-a", "task-b"]),
      task("task-b"),
      task("task-a")
    ]

    assert sorted_names(tasks) == {:ok, ["task-b", "task-a", "task-final"]}
  end

  test "branches and shared dependencies produce a dependency-safe order" do
    tasks = [
      task("build"),
      task("test-api", ["build"]),
      task("test-ui", ["build"]),
      task("package", ["test-api", "test-ui"]),
      task("publish", ["package"])
    ]

    assert {:ok, ordered_tasks} = sort_tasks(tasks)
    assert names(ordered_tasks) == ["build", "test-api", "test-ui", "package", "publish"]
    assert_dependencies_before_tasks(ordered_tasks)
  end

  test "dense acyclic graph uses deterministic request-order tie-breaking" do
    tasks = [
      task("deploy", ["package", "audit"]),
      task("lint", ["checkout"]),
      task("checkout"),
      task("package", ["unit", "integration", "assets"]),
      task("assets", ["checkout"]),
      task("audit", ["lint", "scan"]),
      task("unit", ["compile"]),
      task("scan", ["checkout"]),
      task("compile", ["checkout"]),
      task("integration", ["compile", "assets"])
    ]

    assert {:ok, ordered_tasks} = sort_tasks(tasks)

    assert names(ordered_tasks) == [
             "checkout",
             "lint",
             "assets",
             "scan",
             "audit",
             "compile",
             "unit",
             "integration",
             "package",
             "deploy"
           ]

    assert_dependencies_before_tasks(ordered_tasks)
  end

  test "self-dependency returns dependency_cycle" do
    assert {:error,
            %Error{
              code: "dependency_cycle",
              details: %{"remaining_tasks" => ["task-1"]}
            }} = sorted_names([task("task-1", ["task-1"])])
  end

  test "multi-task cycle returns dependency_cycle" do
    tasks = [
      task("task-1", ["task-2"]),
      task("task-2", ["task-3"]),
      task("task-3", ["task-1"])
    ]

    assert {:error,
            %Error{
              code: "dependency_cycle",
              details: %{"remaining_tasks" => ["task-1", "task-2", "task-3"]}
            }} = sorted_names(tasks)
  end

  test "disconnected graph with one cyclic component returns dependency_cycle" do
    tasks = [
      task("independent"),
      task("cycle-a", ["cycle-b"]),
      task("cycle-b", ["cycle-a"])
    ]

    assert {:error,
            %Error{
              code: "dependency_cycle",
              details: %{"remaining_tasks" => ["cycle-a", "cycle-b"]}
            }} = sorted_names(tasks)
  end

  test "large task lists avoid recursion limits and repeated full-list scans" do
    tasks =
      1..2_000
      |> Enum.map(fn index ->
        name = "task-#{index}"
        requires = if index == 1, do: [], else: ["task-#{index - 1}"]
        task(name, requires)
      end)

    assert {:ok, ordered_tasks} = sort_tasks(tasks)
    assert length(ordered_tasks) == 2_000
    assert List.first(ordered_tasks).name == "task-1"
    assert List.last(ordered_tasks).name == "task-2000"
  end

  test "invariant: every dependency appears before the task that requires it" do
    tasks = [
      task("setup"),
      task("lint", ["setup"]),
      task("compile", ["setup"]),
      task("unit", ["compile"]),
      task("integration", ["compile"]),
      task("release", ["lint", "unit", "integration"])
    ]

    assert {:ok, ordered_tasks} = sort_tasks(tasks)
    assert_dependencies_before_tasks(ordered_tasks)
  end

  defp sorted_names(tasks) do
    case sort_tasks(tasks) do
      {:ok, ordered_tasks} -> {:ok, names(ordered_tasks)}
      {:error, error} -> {:error, error}
    end
  end

  defp sort_tasks(tasks) do
    tasks
    |> job()
    |> DependencyGraph.build()
    |> TopologicalSorter.sort()
  end
end
