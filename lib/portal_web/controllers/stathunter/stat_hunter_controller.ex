defmodule PortalWeb.StatHunter.StatHunterController do
  use PortalWeb, :controller
  
  @doc """
  Controls the flow in the Stathunter page. 
  """
  
  def main(conn, _params) do
    conn
    |> assign(:page, "stat hunter")
    |> render(:sh_main)
  end
end
