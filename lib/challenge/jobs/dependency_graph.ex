defmodule Challenge.Jobs.DependencyGraph do
  @moduledoc """
  Dependency graph built from a validated job.
  """

  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task

  @enforce_keys [:task_by_name, :in_degree, :dependents, :input_index]
  defstruct [:task_by_name, :in_degree, :dependents, :input_index]

  @type task_name :: String.t()

  @type t :: %__MODULE__{
          task_by_name: %{task_name() => Task.t()},
          in_degree: %{task_name() => non_neg_integer()},
          dependents: %{task_name() => [task_name()]},
          input_index: %{task_name() => non_neg_integer()}
        }

  @spec build(Job.t()) :: t()
  def build(%Job{tasks: tasks}) do
    graph = %__MODULE__{
      task_by_name: Map.new(tasks, &{&1.name, &1}),
      in_degree: Map.new(tasks, &{&1.name, length(&1.requires)}),
      dependents: Map.new(tasks, &{&1.name, []}),
      input_index: input_index(tasks)
    }

    dependents =
      tasks
      |> Enum.reduce(graph.dependents, &add_dependent_links/2)
      |> preserve_input_order()

    %__MODULE__{graph | dependents: dependents}
  end

  defp input_index(tasks) do
    tasks
    |> Enum.with_index()
    |> Map.new(fn {task, index} -> {task.name, index} end)
  end

  defp add_dependent_links(task, dependents) do
    Enum.reduce(task.requires, dependents, fn dependency, dependents ->
      Map.update!(dependents, dependency, &[task.name | &1])
    end)
  end

  defp preserve_input_order(dependents) do
    Map.new(dependents, fn {task_name, task_dependents} ->
      {task_name, Enum.reverse(task_dependents)}
    end)
  end
end
