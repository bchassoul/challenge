defmodule ChallengeWeb.ResponseNegotiatorTest do
  use ExUnit.Case, async: true

  alias Challenge.Jobs.Error
  alias ChallengeWeb.ResponseNegotiator

  test "Accept negotiation honors quality values, wildcards, and explicit exclusions" do
    cases = [
      {[], :json},
      {["text/x-shellscript;q=0.9, application/json;q=0.1"], :shell},
      {["application/*"], :json},
      {["text/*"], :shell},
      {["text/x-shellscript;q=0, application/json;q=0.5"], :json},
      {["application/json;q=0, */*"], :shell},
      {["APPLICATION/JSON; Q = 1"], :json}
    ]

    for {accept_headers, expected_format} <- cases do
      assert ResponseNegotiator.negotiate_accept(accept_headers) == {:ok, expected_format}
    end
  end

  test "unsupported Accept returns not_acceptable" do
    assert {:error, %Error{code: "not_acceptable"}} =
             ResponseNegotiator.negotiate_accept(["text/plain"])

    assert {:error, %Error{code: "not_acceptable"}} =
             ResponseNegotiator.negotiate_accept(["application/json;q=0"])

    assert {:error, %Error{code: "not_acceptable"}} =
             ResponseNegotiator.negotiate_accept(["not a media type"])
  end
end
