defmodule Challenge.Jobs.Task do
  @moduledoc """
  A single task in a job.
  """

  @enforce_keys [:name, :command]
  defstruct [:name, :command, requires: []]

  @type t :: %__MODULE__{
          name: String.t(),
          command: String.t(),
          requires: [String.t()]
        }
end
