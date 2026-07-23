defmodule Challenge.Jobs.ValidatorEdgeCasesTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Task
  alias Challenge.Jobs.Validator

  test "unknown atom fields return invalid_payload instead of raising" do
    cases = [
      {%{"tasks" => [], unexpected: true}, :unexpected, "$.unexpected"},
      {
        %{"tasks" => [%{"name" => "task-1", "command" => "echo one", extra: true}]},
        :extra,
        "$.tasks[0].extra"
      }
    ]

    for {payload, field, path} <- cases do
      assert {:error,
              %Error{
                code: "invalid_payload",
                details: %{"field" => ^field, "path" => ^path}
              }} = Validator.validate(payload)
    end
  end

  test "struct payloads are not accepted as decoded JSON objects" do
    assert {:error, %Error{code: "invalid_payload", details: %{"path" => "$"}}} =
             Validator.validate(%Task{name: "task-1", command: "echo one"})
  end
end
