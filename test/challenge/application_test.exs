defmodule Challenge.ApplicationTest do
  use ExUnit.Case, async: true

  test "Cowboy child specs match the application environment" do
    assert Application.fetch_env!(:challenge, :environment) == :test
    assert Challenge.Application.child_specs(:test) == []

    children =
      Challenge.Supervisor
      |> Supervisor.which_children()
      |> Enum.map(fn {id, _pid, _type, _modules} -> id end)

    refute Plug.Cowboy in children

    port = Application.fetch_env!(:challenge, :http_port)

    assert [{Plug.Cowboy, opts}] = Challenge.Application.child_specs(:dev)
    assert opts[:scheme] == :http
    assert opts[:plug] == ChallengeWeb.Router
    assert opts[:options] == [port: port]
  end
end
