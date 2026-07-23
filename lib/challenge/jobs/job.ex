defmodule Challenge.Jobs.Job do
  @moduledoc """
  A validated collection of job tasks.
  """

  defstruct tasks: []

  @type t :: %__MODULE__{
          tasks: [Challenge.Jobs.Task.t()]
        }
end
