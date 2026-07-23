defmodule Challenge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = child_specs(Application.fetch_env!(:challenge, :environment))

    Supervisor.start_link(children, strategy: :one_for_one, name: Challenge.Supervisor)
  end

  def child_specs(:test), do: []

  def child_specs(_environment) do
    [
      {Plug.Cowboy,
       scheme: :http,
       plug: ChallengeWeb.Router,
       options: [port: Application.fetch_env!(:challenge, :http_port)]}
    ]
  end
end
