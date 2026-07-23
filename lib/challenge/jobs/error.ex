defmodule Challenge.Jobs.Error do
  @moduledoc """
  Public domain error returned by job operations.
  """

  @enforce_keys [:code, :message]
  defstruct [:code, :message, details: %{}]

  @type details :: map()

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          details: details()
        }

  @spec new(String.t(), String.t()) :: t()
  @spec new(String.t(), String.t(), details()) :: t()
  def new(code, message, details \\ %{}) do
    %__MODULE__{code: code, message: message, details: details}
  end
end
