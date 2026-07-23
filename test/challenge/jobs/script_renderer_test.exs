defmodule Challenge.Jobs.ScriptRendererTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.ScriptRenderer

  import Challenge.Jobs.TestSupport, only: [task: 2]

  test "bash script includes shebang, sorted commands, and final newline" do
    script =
      ScriptRenderer.render([
        task("task-1", "touch /tmp/file1"),
        task("task-2", "cat /tmp/file1"),
        task("task-3", "rm /tmp/file1")
      ])

    assert script ==
             "#!/usr/bin/env bash\n" <>
               "touch /tmp/file1\n" <>
               "cat /tmp/file1\n" <>
               "rm /tmp/file1\n"

    assert String.starts_with?(script, "#!/usr/bin/env bash\n")
    assert String.ends_with?(script, "\n")
    assert ScriptRenderer.render([]) == "#!/usr/bin/env bash\n"
  end

  test "commands with shell syntax and whitespace are preserved exactly" do
    commands = [
      ~s(echo "Hello World!" > /tmp/file1),
      "cat /tmp/file1 | sed 's/World/BEAM/g'",
      "  printf '%s\\n' \"$HOME\"; test -f /tmp/file1  "
    ]

    script =
      commands
      |> Enum.with_index(1)
      |> Enum.map(fn {command, index} -> task("task-#{index}", command) end)
      |> ScriptRenderer.render()

    assert script ==
             "#!/usr/bin/env bash\n" <>
               "echo \"Hello World!\" > /tmp/file1\n" <>
               "cat /tmp/file1 | sed 's/World/BEAM/g'\n" <>
               "  printf '%s\\n' \"$HOME\"; test -f /tmp/file1  \n"
  end
end
