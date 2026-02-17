defmodule StatHunter do
  alias Req
  @moduledoc """
  Interacts with the Faceit API and performs other operations related to fetching and storing
  data requested by users.
  """

  @faceit "https://open.faceit.com/data/v4/"

  def search_player(name) when is_binary(name) do
    Req.get!(@faceit <> "/search/players",
    params: [nickname: name],
    headers: default_headers())
  end

  defp default_headers() do
    api_key = System.get_env("FACEIT_API_KEY") || Application.get_env(:portal, :FACEIT_API_KEY)

    if api_key == nil, do: raise "FACEIT_API_KEY not set. Aborting."

    [authorization: "Bearer " <> api_key, "content-type": "application/json"]
  end
end
