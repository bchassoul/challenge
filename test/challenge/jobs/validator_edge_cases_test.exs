defmodule Challenge.Jobs.ValidatorEdgeCasesTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias Challenge.Jobs.Task
  alias Challenge.Jobs.Validator

  test "unknown top-level atom fields return invalid_payload instead of raising" do
    assert {:error,
            %Error{
              code: "invalid_payload",
              details: %{"field" => :unexpected, "path" => "$.unexpected"}
            }} = Validator.validate(%{"tasks" => [], unexpected: true})
  end

  test "unknown task atom fields return invalid_payload instead of raising" do
    assert {:error,
            %Error{
              code: "invalid_payload",
              details: %{"field" => :extra, "path" => "$.tasks[0].extra"}
            }} =
             Validator.validate(%{
               "tasks" => [
                 %{"name" => "task-1", "command" => "echo one", extra: true}
               ]
             })
  end

  test "struct payloads are not accepted as decoded JSON objects" do
    assert {:error, %Error{code: "invalid_payload", details: %{"path" => "$"}}} =
             Validator.validate(%Task{name: "task-1", command: "echo one"})
  end
end
