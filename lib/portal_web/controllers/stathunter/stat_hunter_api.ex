defmodule PortalWeb.StatHunter.StatHunterAPI do
  use PortalWeb, :controller
  require Logger

  def find_player(conn, %{"nick" => ""}) do
    Logger.debug([message: "discarding empty request"])
    conn
    |> html(~s(<div id="search-results" style="display: none; opacity: 0;"></div>))
  end
  
  def find_player(conn, %{"nick" => name}) when is_binary(name) do
    list = StatHunter.find_player(name)

    conn
    |> assign(:results, list)
    |> render(:search_result, layout: false)
  end

  def find_player(conn, _params) do
    conn
    |> render(:error)
  end
end
