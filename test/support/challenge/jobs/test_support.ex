defmodule Challenge.Jobs.TestSupport do
  @moduledoc false

  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task

  def job(tasks), do: %Job{tasks: tasks}

  def task(name), do: task(name, "echo #{name}", [])
  def task(name, requires) when is_list(requires), do: task(name, "echo #{name}", requires)
  def task(name, command) when is_binary(command), do: task(name, command, [])

  def task(name, command, requires) do
    %Task{name: name, command: command, requires: requires}
  end

  def names(tasks), do: Enum.map(tasks, & &1.name)

  def challenge_sample_payload do
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

  def dependency_violations(ordered_tasks) do
    position_by_name =
      ordered_tasks
      |> Enum.with_index()
      |> Map.new(fn {task, index} -> {task.name, index} end)

    for task <- ordered_tasks,
        dependency <- task.requires,
        Map.fetch!(position_by_name, dependency) > Map.fetch!(position_by_name, task.name) do
      {task.name, dependency}
    end
  end
end
