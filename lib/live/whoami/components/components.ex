defmodule Live.Whoami.Components do
  use PortalWeb, :live_component

  @moduledoc """
  Holds the components which are the pieces of the game. 
  This is so that this file will store the many pages, 
  while the main liveview will handle the logic behin them
  """

  attr :question, :string, required: true
  attr :button, :string, required: true
  slot :inner_block
  @doc "Renders the welcome screen where one can make a new lobby"
  def new_lobby(assigns) do
    ~H"""
      <div style="display: grid; gap: 10px; justify-contents: center">
        <div >{@question}</div>
        <form phx-submit="request_lobby">
          <div>
            <input
              type="number"
              name="player_count"
              max="20"
              min="3"
              required
              placeholder="Min 3, max 20"
              class="rounded-xl bg-zinc-800"
              style="width: 266px; margin-bottom: 10px"
            />
            </div>
          <div>
            <.button type="submit" style="width: 266px">{@button}</.button>
          </div>
        </form>
        <.link href={~p"/remove-username"}>
          <.button style="width: 266px; justify-self: center"> change username </.button>
        </.link>
      </div>
    """
  end

  attr :lobby_id, :integer, required: true
  attr :self, :map, required: true
  attr :ready, :boolean, required: true
  attr :players, :list, required: true
  slot :inner_block
  
  @doc "Renders the waiting room before the game starts."
  def waiting_room(assigns) do
    is_captain = is_captain?(assigns.lobby_id, assigns.self)
    assigns = Map.put_new(assigns, :is_captain, is_captain)
  
    ~H"""
      <div class="players">
        
        <div class={"player-#{inspect(@ready)}"}>
          <div class="stars">
            <.icon name="hero-star-solid"/>

          </div>
          <.icon name="hero-user" class="icon"/>
          <div class="name">{@self.name}</div>
          <div class="score">{@self.wins}</div>
        </div>
        
        <div class={"player-#{player.ready}"} :if={@players != []} :for={player <- @players}>
        
          <button 
            :if={@is_captain == true} 
            class="remove_player" 
            phx-click="remove_player" 
            phx-value-player={player.user.name}
          >
            <.icon name="hero-x-circle-solid"/>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z" clip-rule="evenodd" />
            </svg>
          </button>
          
          <div class="stars">
            <.icon name="hero-star-solid"/>
          </div>
          <.icon name="hero-user" class="icon"/>
          <div class="name">{player.user.name}</div>
          <div class="score">{player.user.wins}</div>
        </div>
      </div>

      <button 
        class={"ready-" <> inspect(@ready)}
        phx-click="toggle_ready"
        value={@self.name}
      >
      ready, <%= @self.name %>? 
      </button>

      <div class="invite-block">
        <div>invite your friends with this link:</div>
        <div 
            class="invite-link"
            phx-hook="CopyToClipboard"
            data-copy={make_link(@lobby_id)}
            id="link">
          {make_link(@lobby_id)}
          <.icon name="hero-clipboard-document" />
        </div>
      </div>
    """
  end

  # Helpers for the waiting room

  def is_captain?(lobby_id, self) do
    case Whoami.Main.fetch_captain(lobby_id) do
      {:ok, captain} -> if captain.id == self.id, do: true, else: false
      {:error, _reason} -> false
    end
  end

  defp make_link(lobby_id) do
    env = System.get_env("MIX_ENV")
    if env == "dev" do 
      "localhost:4000" <> ~p{/whoami?#{%{lobby: lobby_id}}}
    else 
      System.get_env("PHX_HOST") <> ~p{/whoami?#{%{lobby: lobby_id}}}
    end
  end
end
