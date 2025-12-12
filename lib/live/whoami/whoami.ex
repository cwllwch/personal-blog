defmodule PortalWeb.LiveStuff.WhoAmI do
  require Logger
  use PortalWeb, :live_view
  @moduledoc """
  Orchestrates the game featured in Inglorious Bastards where
  everyone writes a famous person on a card then gets assigned 
  someone else's card. Idea is that everyone plays 
  """
  
  def mount(_params, _session, socket) do
   new_socket = 
    assign(socket,
      page_title: "who am i?"
    )

    {:ok, new_socket}
  end

  def render(assigns) do
    ~H"""
    

    <p></p>
    
    <div class="field"></div>
    """
  end
end
