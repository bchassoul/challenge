defmodule Challenge.Jobs.OrderJob do
  @moduledoc """
  Orders a decoded job payload by dependency.
  """

  alias Challenge.Jobs.DependencyGraph
  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Task
  alias Challenge.Jobs.TopologicalSorter
  alias Challenge.Jobs.Validator

  @type result :: {:ok, [Task.t()]} | {:error, Error.t()}

  @spec call(term()) :: result()
  def call(payload) do
    with {:ok, job} <- Validator.validate(payload) do
      job
      |> DependencyGraph.build()
      |> TopologicalSorter.sort()
    end
  end
end
