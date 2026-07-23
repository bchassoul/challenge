defmodule ChallengeWeb.ResponseNegotiator do
  @moduledoc false

  alias Challenge.Jobs.Error

  import Plug.Conn, only: [get_req_header: 2]

  @supported_response_formats [
    %{format: :json, type: "application", subtype: "json", server_order: 0},
    %{format: :shell, type: "text", subtype: "x-shellscript", server_order: 1}
  ]

  @type format :: :json | :shell
  @type result :: {:ok, format()} | {:error, Error.t()}

  @spec negotiate(Plug.Conn.t()) :: result()
  def negotiate(conn) do
    conn
    |> get_req_header("accept")
    |> negotiate_accept()
  end

  @spec negotiate_accept([String.t()]) :: result()
  def negotiate_accept([]), do: {:ok, :json}

  def negotiate_accept(accept_headers) do
    accept_headers
    |> Enum.join(",")
    |> accepted_response_format()
  end

  defp accepted_response_format(accept_header) do
    media_ranges =
      accept_header
      |> Plug.Conn.Utils.list()
      |> Enum.map(&parse_media_range/1)
      |> Enum.with_index()
      |> Enum.map(fn {media_range, index} -> Map.put(media_range, :index, index) end)

    @supported_response_formats
    |> Enum.map(&response_format_candidate(&1, media_ranges))
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1.q <= 0.0))
    |> Enum.sort_by(fn candidate ->
      {-candidate.q, -candidate.specificity, candidate.index, candidate.server_order}
    end)
    |> List.first()
    |> case do
      nil -> {:error, Error.new("not_acceptable", "Requested response format is not supported.")}
      candidate -> {:ok, candidate.format}
    end
  end

  defp parse_media_range(value) do
    case Plug.Conn.Utils.media_type(value) do
      {:ok, type, subtype, params} ->
        %{
          type: type,
          subtype: subtype,
          specificity: media_range_specificity(type, subtype),
          q: quality(params)
        }

      :error ->
        %{type: "", subtype: "", specificity: 2, q: 0.0}
    end
  end

  defp media_range_specificity("*", "*"), do: 0
  defp media_range_specificity(_type, "*"), do: 1
  defp media_range_specificity(_type, _subtype), do: 2

  defp quality(%{"q" => value}) do
    parse_quality(value)
  end

  defp quality(_params), do: 1.0

  defp parse_quality(value) do
    case Float.parse(value) do
      {q, ""} when q >= 0.0 and q <= 1.0 -> q
      _invalid -> 0.0
    end
  end

  defp response_format_candidate(format, media_ranges) do
    media_ranges
    |> Enum.filter(&media_range_matches?(&1, format))
    |> Enum.sort_by(fn media_range -> {-media_range.specificity, media_range.index} end)
    |> List.first()
    |> case do
      nil ->
        nil

      media_range ->
        %{
          format: format.format,
          q: media_range.q,
          specificity: media_range.specificity,
          index: media_range.index,
          server_order: format.server_order
        }
    end
  end

  defp media_range_matches?(%{type: "*", subtype: "*"}, _format), do: true
  defp media_range_matches?(%{type: type, subtype: "*"}, %{type: type}), do: true

  defp media_range_matches?(%{type: type, subtype: subtype}, %{type: type, subtype: subtype}),
    do: true

  defp media_range_matches?(_media_range, _format), do: false
end
