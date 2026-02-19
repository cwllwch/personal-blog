defmodule StatHunter do
  alias Req
  require Logger
  @moduledoc """
  Interacts with the Faceit API and performs other operations related to fetching and storing
  data requested by users.
  """

  @faceit "https://open.faceit.com/data/v4"

  def find_player(name) when is_binary(name) do
    req = request_search_player(name)
      cond do 
      req.status == 200 -> 
        Logger.debug([message: "Got OK response", module: __MODULE__])
        req.body
        |> Map.get("items")
      req.status == 400 ->
        error = req.body |> Jason.decode() |> elem(1) |> Map.get("error")
        Logger.error([message: "Got an error response", error: error])
        nil
      true ->
        Logger.error(message: "Unexpected response from upstream", status_code: req.status, body: req.body)
        nil
      end
    rescue 
    e -> 
      Logger.error([message: "Error in the HTTP client, can't issue request", error: inspect(e)])
      nil
  end

  defp request_search_player(name) do
    Req.get!(
      @faceit <> "/search/players",
      params: [nickname: name],
      headers: default_headers()
    )
  end 

  defp default_headers() do
    api_key = System.get_env("FACEIT_API_KEY") || Application.get_env(:portal, :FACEIT_API_KEY)

    if api_key == nil, do: raise "FACEIT_API_KEY not set. Aborting."

    [authorization: "Bearer " <> api_key, "content-type": "application/json"]
  end

  def list_games(games) do
    Enum.sort_by(games, &(&1["skill_level"]), :desc)
    |> Enum.map(fn i -> i["name"] end)
    |> Enum.join(" | ")
  end
end
