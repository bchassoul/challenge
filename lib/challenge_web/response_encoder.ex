defmodule ChallengeWeb.ResponseEncoder do
  @moduledoc """
  Encodes public JSON response bodies.
  """

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Task

  @spec encode_tasks([Task.t()]) :: binary()
  def encode_tasks(tasks) do
    %{"tasks" => Enum.map(tasks, &task_body/1)}
    |> JSON.encode!()
  end

  @spec encode_error(Error.t()) :: binary()
  def encode_error(%Error{} = error) do
    %{
      "error" => %{
        "code" => error.code,
        "message" => error.message,
        "details" => error.details
      }
    }
    |> JSON.encode!()
  end

  defp task_body(task) do
    %{
      "name" => task.name,
      "command" => task.command
    }
  end
end
