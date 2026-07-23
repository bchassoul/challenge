defmodule ChallengeWeb.Router do
  @moduledoc false

  use Plug.Router

  alias Challenge.Jobs.Error
  alias ChallengeWeb.ErrorJSON

  plug(:match)
  plug(:dispatch)

  post "/jobs" do
    ChallengeWeb.JobController.create(conn)
  end

  match _ do
    ErrorJSON.send_json(
      conn,
      404,
      Error.new("not_found", "The requested resource was not found.")
    )
  end
end
