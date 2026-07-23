defmodule Challenge.Jobs.TopologicalSorter do
  @moduledoc """
  Sorts dependency graphs into deterministic task order.
  """

  alias Challenge.Jobs.DependencyGraph
  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Task

  @type result :: {:ok, [Task.t()]} | {:error, Error.t()}

  @spec sort(DependencyGraph.t()) :: result()
  def sort(%DependencyGraph{} = graph) do
    total_count = map_size(graph.task_by_name)

    graph
    |> initial_ready_set()
    |> sort_ready(graph, graph.in_degree, [], 0, total_count)
  end

  defp sort_ready(_ready, _graph, _in_degree, ordered_tasks, total_count, total_count) do
    {:ok, Enum.reverse(ordered_tasks)}
  end

  defp sort_ready(ready, graph, in_degree, ordered_tasks, emitted_count, total_count) do
    if :gb_sets.is_empty(ready) do
      dependency_cycle_error(graph, in_degree)
    else
      emit_next_ready(ready, graph, in_degree, ordered_tasks, emitted_count, total_count)
    end
  end

  defp emit_next_ready(ready, graph, in_degree, ordered_tasks, emitted_count, total_count) do
    {{_input_index, task_name}, ready} = :gb_sets.take_smallest(ready)
    task = Map.fetch!(graph.task_by_name, task_name)
    dependents = Map.fetch!(graph.dependents, task_name)
    {in_degree, ready} = unlock_dependents(dependents, graph, in_degree, ready)

    sort_ready(ready, graph, in_degree, [task | ordered_tasks], emitted_count + 1, total_count)
  end

  defp initial_ready_set(graph) do
    Enum.reduce(graph.in_degree, :gb_sets.empty(), fn
      {task_name, 0}, ready ->
        insert_ready(ready, graph, task_name)

      {_task_name, _in_degree}, ready ->
        ready
    end)
  end

  defp unlock_dependents(dependents, graph, in_degree, ready) do
    Enum.reduce(dependents, {in_degree, ready}, fn dependent, {in_degree, ready} ->
      new_degree = Map.fetch!(in_degree, dependent) - 1
      in_degree = Map.put(in_degree, dependent, new_degree)

      {in_degree, maybe_insert_ready(new_degree, ready, graph, dependent)}
    end)
  end

  defp maybe_insert_ready(0, ready, graph, task_name), do: insert_ready(ready, graph, task_name)
  defp maybe_insert_ready(_degree, ready, _graph, _task_name), do: ready

  defp insert_ready(ready, graph, task_name) do
    :gb_sets.insert({Map.fetch!(graph.input_index, task_name), task_name}, ready)
  end

  defp dependency_cycle_error(graph, in_degree) do
    remaining_tasks =
      in_degree
      |> Enum.filter(fn {_task_name, degree} -> degree > 0 end)
      |> Enum.map(fn {task_name, _degree} -> task_name end)
      |> Enum.sort_by(&Map.fetch!(graph.input_index, &1))

    {:error,
     Error.new("dependency_cycle", "Dependency cycle detected.", %{
       "remaining_tasks" => remaining_tasks
     })}
  end
end
