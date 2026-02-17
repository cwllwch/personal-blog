defmodule PortalWeb.StatHunter.StatHunterAPI do
  use PortalWeb, :controller

  def find_player(conn, %{"nick" => name}) when is_binary(name) do
    conn
    |> render(:search_result, layout: false)
  end

  def find_player(conn, _params) do
    conn
    |> render(:error)
  end
end
