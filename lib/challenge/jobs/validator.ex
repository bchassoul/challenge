defmodule Challenge.Jobs.Validator do
  @moduledoc """
  Validates decoded job payloads and builds domain structs.
  """

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Job
  alias Challenge.Jobs.Task

  @top_level_fields ["tasks"]
  @task_fields ["command", "name", "requires"]

  @type result :: {:ok, Job.t()} | {:error, Error.t()}

  @spec validate(term()) :: result()
  def validate(payload) when is_map(payload) do
    if is_struct(payload) do
      invalid_payload("Payload must be an object.", %{"path" => "$"})
    else
      with :ok <- reject_unknown_fields(payload, @top_level_fields, "$"),
           {:ok, tasks_payload} <- fetch_required(payload, "tasks", "$"),
           :ok <- require_list(tasks_payload, "$.tasks"),
           {:ok, tasks} <- validate_tasks(tasks_payload),
           :ok <- reject_duplicate_task_names(tasks),
           :ok <- reject_duplicate_dependencies(tasks),
           :ok <- reject_unknown_dependencies(tasks) do
        {:ok, %Job{tasks: tasks}}
      end
    end
  end

  def validate(_payload), do: invalid_payload("Payload must be an object.", %{"path" => "$"})

  defp validate_tasks(tasks_payload) do
    tasks_payload
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {task_payload, index}, {:ok, tasks} ->
      case validate_task(task_payload, index) do
        {:ok, task} -> {:cont, {:ok, [task | tasks]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, tasks} -> {:ok, Enum.reverse(tasks)}
      {:error, error} -> {:error, error}
    end
  end

  defp validate_task(task_payload, index) when is_map(task_payload) do
    if is_struct(task_payload) do
      invalid_payload("Task must be an object.", %{"path" => task_path(index)})
    else
      with :ok <- reject_unknown_fields(task_payload, @task_fields, task_path(index)),
           {:ok, name} <- fetch_required(task_payload, "name", task_path(index)),
           :ok <- require_string(name, "#{task_path(index)}.name"),
           {:ok, command} <- fetch_required(task_payload, "command", task_path(index)),
           :ok <- require_string(command, "#{task_path(index)}.command"),
           {:ok, requires} <- fetch_optional_requires(task_payload, index) do
        {:ok, %Task{name: name, command: command, requires: requires}}
      end
    end
  end

  defp validate_task(_task_payload, index) do
    invalid_payload("Task must be an object.", %{"path" => task_path(index)})
  end

  defp fetch_required(map, field, parent_path) do
    if Map.has_key?(map, field) do
      {:ok, Map.fetch!(map, field)}
    else
      invalid_payload("Missing required field.", %{
        "field" => field,
        "path" => "#{parent_path}.#{field}"
      })
    end
  end

  defp fetch_optional_requires(task_payload, index) do
    requires = Map.get(task_payload, "requires", [])
    path = "#{task_path(index)}.requires"

    with :ok <- require_list(requires, path),
         :ok <- require_dependency_names(requires, path) do
      {:ok, requires}
    end
  end

  defp require_list(value, _path) when is_list(value), do: :ok

  defp require_list(_value, path) do
    invalid_payload("Field must be a list.", %{"path" => path})
  end

  defp require_string(value, _path) when is_binary(value), do: :ok

  defp require_string(_value, path) do
    invalid_payload("Field must be a string.", %{"path" => path})
  end

  defp require_dependency_names(requires, path) do
    requires
    |> Enum.with_index()
    |> Enum.find(fn {dependency, _index} -> not is_binary(dependency) end)
    |> case do
      nil ->
        :ok

      {_dependency, index} ->
        invalid_payload("Dependency name must be a string.", %{"path" => "#{path}[#{index}]"})
    end
  end

  defp reject_unknown_fields(map, allowed_fields, parent_path) do
    map
    |> Map.keys()
    |> Enum.reject(&(&1 in allowed_fields))
    |> case do
      [] ->
        :ok

      [field | _rest] ->
        invalid_payload("Unknown field.", %{
          "field" => field,
          "path" => "#{parent_path}.#{field}"
        })
    end
  end

  defp reject_duplicate_task_names(tasks) do
    tasks
    |> Enum.with_index()
    |> Enum.reduce_while(%{}, fn {task, index}, seen ->
      case Map.fetch(seen, task.name) do
        {:ok, first_index} ->
          error =
            Error.new("duplicate_task_name", "Duplicate task name.", %{
              "name" => task.name,
              "path" => "#{task_path(index)}.name",
              "first_path" => "#{task_path(first_index)}.name"
            })

          {:halt, {:error, error}}

        :error ->
          {:cont, Map.put(seen, task.name, index)}
      end
    end)
    |> case do
      {:error, error} -> {:error, error}
      _seen -> :ok
    end
  end

  defp reject_duplicate_dependencies(tasks) do
    tasks
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {task, task_index}, :ok ->
      case find_duplicate_dependency(task.requires) do
        nil ->
          {:cont, :ok}

        {dependency, first_index, duplicate_index} ->
          error =
            Error.new("duplicate_dependency", "Duplicate dependency.", %{
              "task" => task.name,
              "dependency" => dependency,
              "path" => "#{task_path(task_index)}.requires[#{duplicate_index}]",
              "first_path" => "#{task_path(task_index)}.requires[#{first_index}]"
            })

          {:halt, {:error, error}}
      end
    end)
  end

  defp find_duplicate_dependency(requires) do
    requires
    |> Enum.with_index()
    |> Enum.reduce_while(%{}, fn {dependency, index}, seen ->
      case Map.fetch(seen, dependency) do
        {:ok, first_index} -> {:halt, {dependency, first_index, index}}
        :error -> {:cont, Map.put(seen, dependency, index)}
      end
    end)
    |> case do
      %{} -> nil
      duplicate -> duplicate
    end
  end

  defp reject_unknown_dependencies(tasks) do
    task_names = MapSet.new(tasks, & &1.name)

    tasks
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {task, task_index}, :ok ->
      case find_unknown_dependency(task.requires, task_names) do
        nil ->
          {:cont, :ok}

        {dependency, dependency_index} ->
          error =
            Error.new("unknown_dependency", "Unknown dependency.", %{
              "task" => task.name,
              "dependency" => dependency,
              "path" => "#{task_path(task_index)}.requires[#{dependency_index}]"
            })

          {:halt, {:error, error}}
      end
    end)
  end

  defp find_unknown_dependency(requires, task_names) do
    requires
    |> Enum.with_index()
    |> Enum.find(fn {dependency, _index} -> not MapSet.member?(task_names, dependency) end)
  end

  defp invalid_payload(message, details) do
    {:error, Error.new("invalid_payload", message, details)}
  end

  defp task_path(index), do: "$.tasks[#{index}]"
end
