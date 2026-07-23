defmodule Challenge.Jobs.ScriptRenderer do
  @moduledoc """
  Renders ordered job tasks as a bash script.
  """

  alias Challenge.Jobs.Task

  @shebang "#!/usr/bin/env bash"

  @spec render([Task.t()]) :: binary()
  def render(tasks) do
    commands = Enum.map(tasks, & &1.command)
    Enum.join([@shebang | commands], "\n") <> "\n"
  end
end
