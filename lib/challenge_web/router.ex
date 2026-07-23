defmodule ChallengeWeb.Router do
  @moduledoc false

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  post "/jobs" do
    ChallengeWeb.JobController.create(conn)
  end

  match _ do
    ChallengeWeb.ErrorJSON.send_json(
      conn,
      404,
      "not_found",
      "The requested resource was not found."
    )
  end
end
