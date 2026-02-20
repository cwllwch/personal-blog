defmodule PortalWeb.StatHunter.StatHunterAPI do
  use PortalWeb, :controller
  require Logger

  def find_player(conn, %{"nick" => ""}) do
    Logger.debug([message: "discarding empty request"])
    conn
    |> html(~s(<div id="search-results" style="display: none; opacity: 0;"></div>))
  end
  
  def find_player(conn, %{"nick" => name}) when is_binary(name) do
    # list = StatHunter.find_player(name)

    list = [
  %{
    "avatar" => "https://assets.faceit-cdn.net/avatars/c75ed657-97c3-4f7c-8334-29f1367416a5_1597802336385.jpg",
    "country" => "BR",
    "games" => [
      %{"name" => "cs2", "skill_level" => "7"},
      %{"name" => "csgo", "skill_level" => "2"}
    ],
    "nickname" => "berniss",
    "player_id" => "c75ed657-97c3-4f7c-8334-29f1367416a5",
    "status" => "",
    "verified" => false
  },
  %{
    "avatar" => "https://assets.faceit-cdn.net/avatars/330c5b3e-89ee-4296-b608-11c1ae6607b4_1632185535590.jpg",
    "country" => "AR",
    "games" => [%{"name" => "csgo", "skill_level" => "3"}],
    "nickname" => "Berniss01",
    "player_id" => "330c5b3e-89ee-4296-b608-11c1ae6607b4",
    "status" => "",
    "verified" => false
  },
  %{
    "avatar" => "https://assets.faceit-cdn.net/avatars/154fcc14-98a4-44d2-90bb-63d3838ba72c_1616519634999.jpg",
    "country" => "CL",
    "games" => [
      %{"name" => "tf2", "skill_level" => "2"},
      %{"name" => "valorant", "skill_level" => "3"}
    ],
    "nickname" => "bernissj",
    "player_id" => "154fcc14-98a4-44d2-90bb-63d3838ba72c",
    "status" => "",
    "verified" => false
  },
  %{
    "avatar" => "https://distribution.faceit-cdn.net/images/bbe2ca6b-48bc-4b44-9f54-db9c6e6b6927.jpeg",
    "country" => "PT",
    "games" => [%{"name" => "cs2", "skill_level" => "3"}],
    "nickname" => "bernissio",
    "player_id" => "0b7dec4b-6ddf-41fc-b3c4-0dbe9dc9bd95",
    "status" => "",
    "verified" => false
  }
]

    conn
    |> assign(:results, list)
    |> render(:search_result, layout: false)
  end

  def find_player(conn, _params) do
    conn
    |> render(:error)
  end
end
