defmodule ChallengeWeb.JobController do
  @moduledoc false

  alias ChallengeWeb.ErrorJSON

  def create(conn) do
    ErrorJSON.send_json(
      conn,
      501,
      "not_implemented",
      "Not implemented yet."
    )
  end
end
