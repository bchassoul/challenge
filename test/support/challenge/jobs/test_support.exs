defmodule Challenge.Jobs.TestSupport do
  @moduledoc false

  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task

  import ExUnit.Assertions

  def job(tasks), do: %Job{tasks: tasks}

  def task(name), do: task(name, "echo #{name}", [])
  def task(name, requires) when is_list(requires), do: task(name, "echo #{name}", requires)
  def task(name, command) when is_binary(command), do: task(name, command, [])

  def task(name, command, requires) do
    %Task{name: name, command: command, requires: requires}
  end

  def names(tasks), do: Enum.map(tasks, & &1.name)

  def assert_dependencies_before_tasks(ordered_tasks) do
    position_by_name =
      ordered_tasks
      |> Enum.with_index()
      |> Map.new(fn {task, index} -> {task.name, index} end)

    for task <- ordered_tasks, dependency <- task.requires do
      assert Map.fetch!(position_by_name, dependency) < Map.fetch!(position_by_name, task.name)
    end
  end
end
