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
  attr :players, :list, required: true
  slot :inner_block

  def waiting_room(assigns) do
    ~H"""
      <div class="players" :if={@players != []}>
          <div class="player" :for={player <- @players}>
          <div class="stars">
            <.icon name="hero-star-solid"/>
          </div>
          <.icon name="hero-user" class="icon"/>
          <div class="name">{player.user.name}</div>
          <div class="score">{player.user.wins}</div>
          </div>
      </div>
      You are in lobby {@lobby_id}

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

  defp make_link(lobby_id) do
env = System.get_env("MIX_ENV")
    if env == "dev" do 
      "localhost:4000" <> ~p{/whoami?#{%{lobby: lobby_id}}}
    else 
      System.get_env("PHX_HOST") <> ~p{/whoami?#{%{lobby: lobby_id}}}
    end
  end
end
