defmodule Live.Whoami.Components do
  alias Whoami.Main, as: Lobby
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
  attr :can_start, :boolean
  slot :inner_block
  
  @doc "Renders the waiting room before the game starts."
  def waiting_room(assigns) do
    is_captain = captain?(assigns.lobby_id, assigns.self)
    assigns = 
      Map.put_new(assigns, :is_captain, is_captain)

    ~H"""
      <button 
        class={"ready-" <> inspect(@self.ready)}
        phx-click="toggle_ready"
        value={@self.name}
      >
        <span :if={@self.ready and @can_start == false}>
          <div class="loading-dots"></div> waiting for others <div class="loading-dots"></div>
        </span>

        <span :if={@self.ready and @can_start == true} class="justify-self-center">
          <div class="loading-dots"></div> everyone is ready! <div class="loading-dots"></div>
        </span>
        
        <span :if={!@self.ready}>ready now, <%= @self.name %>?</span>
      </button>

      <button 
        :if={@can_start == true and @is_captain == true} 
        phx-click="start_game"
        class="start"
      >
      start the game!
      </button>
      
      <div class="info"
        :if={@can_start == true and @is_captain == false} 
      >
      waiting for the captain to start...
      </div>


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



  defp make_link(lobby_id) do
    env = System.get_env("MIX_ENV")
    if env == "dev" do 
      "localhost:4000" <> ~p{/whoami?#{%{lobby: lobby_id}}}
    else 
      System.get_env("PHX_HOST") <> ~p{/whoami?#{%{lobby: lobby_id}}}
    end
  end

  attr :lobby_id, :integer, required: true
  attr :self, :map, required: true
  attr :players, :list, required: true
  attr :disc_list, :list, required: true
  attr :stage, :atom, required: true

  @doc "Renders the input page when you need to request a word from the user."
  def player_bar(assigns) do
    captain = captain?(assigns.lobby_id, assigns.self)
    assigns = 
      Map.put_new(assigns, :captain, captain)

    ~H"""
      <div class="players">
        
        <div :if={@stage == :waiting_room} class={"player-#{@self.ready}"}>
        <div class="stars">
            <.icon :if={@self.wins >= 1} :for={win <- 1..@self.wins} name="hero-star-solid"/>
          </div>
          <.icon name="hero-user" class="icon"/>
          <div class="name">{@self.name}</div>
          <div class="score">{@self.wins}</div>
        </div>

        <div :if={@stage != :waiting_room} class={"player-true"}>
        <div class="stars">
            <.icon :if={@self.wins >= 1} :for={win <- 1..@self.wins} name="hero-star-solid"/>
          </div>
          <.icon name="hero-user" class="icon"/>
          <div class="name">{@self.name}</div>
          <div class="score">{@self.wins}</div>
        </div>
        
        <div :for={player <- @players} :if={@stage == :waiting_room} class={"player-#{player.ready}"}> 
            <button 
              :if={@captain == @self.id} 
              class="remove_player" 
              phx-click="remove_player" 
              phx-value-player={player.name}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z" clip-rule="evenodd" />
              </svg>
            </button>
            
            <div class="stars">
              <.icon :if={player.wins >= 1} :for={win <- 1..player.wins} name="hero-star-solid"/>
            </div>
            <.icon :if={player.id not in @disc_list} name="hero-user" class="icon"/>
            <.icon :if={player.id in @disc_list} name="hero-signal-slash" class="icon"/>
            <div class="name">{player.name}</div>
            <div class="score">{player.wins}</div>
        </div>
        <div :for={player <- @players} :if={@stage != :waiting_room} class={"player-true"}> 
            <button 
              :if={@captain == @self.id} 
              class="remove_player" 
              phx-click="remove_player" 
              phx-value-player={player.name}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z" clip-rule="evenodd" />
              </svg>
            </button>
            
            <div class="stars">
              <.icon :if={player.wins >= 1} :for={win <- 1..player.wins} name="hero-star-solid"/>
            </div>
            <.icon :if={player.id not in @disc_list} name="hero-user" class="icon"/>
            <.icon :if={player.id in @disc_list} name="hero-signal-slash" class="icon"/>
            <div class="name">{player.name}</div>
            <div class="score">{player.wins}</div>
        </div>
      </div>
    """
  end

  # Helpers for the player_bar
  def captain?(lobby_id, self) do
    case Whoami.Main.fetch_captain(lobby_id) do
      {:ok, captain} -> captain.id 
      {:error, _reason} -> false
    end
  end

  attr :lobby_id, :integer, required: true
  attr :self, :map, required: true
  attr :players, :list, required: true

  @doc "Renders the input form for getting the words to be guessed. How many words each user inputs 
  decreases with the amount of users in the lobby."
  def input_word(assigns) do
    already_sent = check_word_list(assigns.lobby_id)
    if assigns.self.id in already_sent, do: send(self(), {:update_stage, :waiting_for_words})
    ~H"""
      <form phx-submit="enter_words">
        <div 
          style="
              display: flex;
              width: 100%;
              height: 50vh;
              text-align: center;
              justify-content: center;
              flex-direction: column; 
              align-items: center;
              vertical-align: middle;
              gap: 40px;"
        >
        <h1> think of objects, people, or characters <br>known by everyone in the group </h1>
        <input 
          name="word_1"
          type="text" 
          required
          placeholder="One word, please"
          class="rounded-xl bg-zinc-800"
          style="width: 5vi; min-width: 300px; max-width: 500px"
        />

        <input 
          :if={length(@players) <= 3}
          name="word_2"
          type="text" 
          required
          placeholder="yea imma need another one"
          class="rounded-xl bg-zinc-800"
          style="width: 5vi; min-width: 300px; max-width: 500px"
        />
        
        <input 
          :if={length(@players) == 2}
          name="word_3"
          type="text" 
          required
          placeholder="gib moar word!"
          class="rounded-xl bg-zinc-800"
          style="width: 5vi; min-width: 300px; max-width: 500px"
        />

        <.button 
          style="width: 5vi; min-width: 300px; max-width: 500px; height: 8em"
          type="submit"
        > 
          done
        </.button>

        <p style="font-family: monospace; align-self: end;"> If you choose something weird or too unknown, the other players can 
        challenge the word and vote to eliminate the word.
        <b style="color: white">You will lose a point if your word is voted out!</b></p>
        </div>
      </form>
    """
  end

  # Word input helpers
  defp check_word_list(lobby) do
    Lobby.fetch_word_list(lobby)
  end

  attr :lobby_id, :integer, required: true
  attr :self, :map, required: true
  attr :players, :list, required: true

  @doc "Handles the arena logic. Will reach out to the server for the information it needs."
  def arena(assigns) do
    ~H"""
    <%= inspect(@disc_list, pretty: true) %>
    <br>You got here!
    """
  end

  # Arena helpers
end
