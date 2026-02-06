defmodule Live.Whoami.Components do
  alias Whoami.Main, as: Whoami
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
      <div>{@question}</div>
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
    is_captain = captain?(assigns.lobby_id)

    assigns =
      Map.put_new(assigns, :is_captain, is_captain)

    ~H"""
    <button
      class={"ready-" <> inspect(@self.ready)}
      phx-click="toggle_ready"
    >
      <span :if={@self.ready and @can_start == false}>
        <div class="loading-dots"></div>
        waiting for others
        <div class="loading-dots"></div>
      </span>

      <span :if={@self.ready and @can_start == true} class="justify-self-center">
        <div class="loading-dots"></div>
        everyone is ready!
        <div class="loading-dots"></div>
      </span>

      <span :if={!@self.ready}>ready now, {@self.name}?</span>
    </button>

    <button
      :if={@can_start == true and @is_captain == @self.id}
      phx-click="start_game"
      class="start"
    >
      start the game!
    </button>

    <div
      :if={@can_start == true and @is_captain != @self.id}
      class="info"
    >
      waiting for the captain to start...
    </div>

    <div class="invite-block">
      <div>invite your friends with this link:</div>
      <div
        class="invite-link"
        phx-hook="CopyToClipboard"
        data-copy={make_link(@lobby_id)}
        id="link"
      >
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
    captain = captain?(assigns.lobby_id)

    ordered = assigns.players |> Enum.sort_by(& &1.points, :desc)

    assigns =
      Map.put_new(assigns, :captain, captain)
      |> Map.put(:players, ordered)

    ~H"""
    <div class="players">
      <%!-- This will separate the current player from others - so that the player is always first when viewing itself  --%>
      <div :if={@stage == :waiting_room} class={"player-#{@self.ready}"}>
        <div class="stars">
          <.icon :for={win <- 1..@self.wins} :if={@self.wins >= 1} name="hero-star-solid" />
        </div>
        <.icon :if={@captain != @self.id} name="hero-user" class="icon" />
        <.icon :if={@captain == @self.id} name="hero-user-plus" class="icon" />
        <div class="name">{@self.name}</div>
        <div class="score">{@self.points}</div>
      </div>

      <%!-- Renders the player first in the room, when the ready state does not matter anymore  --%>
      <div :if={@stage != :waiting_room} class="player-true">
        <div class="stars">
          <.icon :for={win <- 1..@self.wins} :if={@self.wins >= 1} name="hero-star-solid" />
        </div>
        <.icon :if={@captain != @self.id} name="hero-user" class="icon" />
        <.icon :if={@captain == @self.id} name="hero-user-plus" class="icon" />
        <div class="name">{@self.name}</div>
        <div class="score">{@self.points}</div>
      </div>

      <%!-- Renders the player list for the waiting room - where ready state determines the color of player bg --%>
      <div :for={player <- @players} :if={@stage == :waiting_room} class={"player-#{player.ready}"}>
        <button
          :if={@captain == @self.id}
          class="remove_player"
          phx-click="remove_player"
          phx-value-player={player.name}
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z"
              clip-rule="evenodd"
            />
          </svg>
        </button>

        <div class="stars">
          <.icon :for={win <- 1..player.wins} :if={player.wins >= 1} name="hero-star-solid" />
        </div>
        <%= if player.id not in @disc_list do %>
          <.icon :if={@captain != player.id} name="hero-user" class="icon" />
          <.icon :if={@captain == player.id} name="hero-user-plus" class="icon" />
        <% else %>
          <.icon name="hero-signal-slash" class="icon" />
        <% end %>
        <div class="name">{player.name}</div>
        <div class="score">{player.points}</div>
      </div>

      <%!-- Renders the player list for stages that are not the waiting room - where ready status doesn't matter --%>
      <div :for={player <- @players} :if={@stage != :waiting_room} class="player-true">
        <button
          :if={@captain == @self.id}
          class="remove_player"
          phx-click="remove_player"
          phx-value-player={player.name}
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z"
              clip-rule="evenodd"
            />
          </svg>
        </button>

        <div class="stars">
          <.icon :for={win <- 1..player.wins} :if={player.wins >= 1} name="hero-star-solid" />
        </div>
        <%= if player.id not in @disc_list do %>
          <.icon :if={@captain != player.id} name="hero-user" class="icon" />
          <.icon :if={@captain == player.id} name="hero-user-plus" class="icon" />
        <% else %>
          <.icon name="hero-signal-slash" class="icon" />
        <% end %>
        <div class="name">{player.name}</div>
        <div class="score">{player.points}</div>
      </div>
    </div>
    """
  end

  # Helpers for the player_bar
  def captain?(lobby_id) do
    case Whoami.fetch_captain(lobby_id) do
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
      <div style="
              display: flex;
              width: 100%;
              height: 50vh;
              min-height: 520px;
              text-align: center;
              justify-content: center;
              flex-direction: column; 
              align-items: center;
              vertical-align: middle;
              gap: 40px;
              margin-top: 10px">
        <h1>think of objects, people, or characters <br />known by everyone in the group</h1>
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

        <p style="font-family: monospace; align-self: end;">
          If you choose something weird or too unknown, the other players can
          challenge the word and vote to eliminate the word. <br />
          <b style="color: white">You will lose a point if your word is voted out!</b>
        </p>
      </div>
    </form>
    """
  end

  # Word input helpers
  defp check_word_list(lobby) do
    Whoami.fetch_word_list(lobby)
    |> Map.keys()
  end

  attr :lobby_id, :integer, required: true
  attr :self, :map, required: true
  attr :players, :list, required: true
  attr :word_in_play, :string, required: true
  attr :player_to_guess, :map, required: true

  @doc "Handles the arena logic. Will reach out to the server for the information it needs."
  def arena(assigns) do
    ~H"""
    <div :if={@player_to_guess != nil and @player_to_guess.id != @self.id}>
      <br />The word this turn is: {@word_in_play}
      <br />to be guessed by: {@player_to_guess.name}
      <br />
      <br />The answer to {@player_to_guess.name}'s question is:
      <div class="button-grid">
        <.button
          class="button-yes"
          phx-click="answer_yes"
        >
          yes!)))
        </.button>

        <.button
          class="button-maybe"
          phx-click="answer_maybe"
        >
          maybe?
        </.button>

        <.button
          class="button-no"
          phx-click="answer_no"
        >
          no(((
        </.button>

        <.button
          class="button-illegal"
          phx-click="illegal_question"
        >
          illegal question!
        </.button>

        <.button
          class="button-stupid"
          phx-click="illegal_word"
        >
          this word is terrible
        </.button>
      </div>
    </div>

    <div :if={@player_to_guess != nil and @player_to_guess.id == @self.id}>
      Think and make a yes or no question.
      your friends will answer, and they will be the judge of your question! <br />
      <br />
      <form
        phx-submit="guess_attempt"
        style="display: flex; flex-direction: column; align-items: center; margin-top:5vh"
      >
        <span>or try your luck guessing the word:</span>
        <input
          name="attempt"
          type="text"
          required
          placeholder="you will lose a question."
          class="rounded-xl bg-zinc-800"
          style="width: 10vw; min-width: 350px; max-width: 500px; margin: 1vh"
        />
        <.button type="submit" style="padding: 3vw; width: 150px">confirm</.button>
      </form>
    </div>

    <div :if={@player_to_guess == nil}>
      <div class="justify-self-center justify-center">
        <.icon name="hero-arrow-path" class="animate-spin text-white" /> loading word...
      </div>
    </div>
    """
  end

  attr :word_in_play, :string, required: true
  attr :guesser, :string, required: true
  attr :guess_word, :string, required: true
  attr :result, :atom, required: true

  def guess_result(assigns) do
    cond do
      assigns.result == :correct ->
        ~H"""
        {@guesser.name} guessed <b>"{@word_in_play}"</b> exactly right, gaining
        + 500 points!
        """

      assigns.result == :close ->
        ~H"""
        {@guesser.name} tried <b>"{@guess_word}"</b>
        and that's not quite right. <br /><br />
        It was a close attempt, but one chance has still been consumed!
        """

      assigns.result == :wrong ->
        ~H"""
        {@guesser.name} tried <b>"{@guess_word}"</b>
        which is completely off the mark. <br /><br />
        In doing so, {@guesser.name} used a chance to ask stuff!
        """
        true -> 
        ~H"""
        {inspect(@result)}
        """
    end
  end

  attr :players, :list, required: true
  attr :self, :map, required: true

  def final_result(assigns) do
    all_players =
      (assigns.players ++ [assigns.self])
      |> Enum.sort_by(& &1.points, :desc)
      |> get_position()

    assigns = assign(assigns, :players, all_players)

    ~H"""
    final standings:
    <div :for={player <- @players}>
      <div style={"#{div_selector(player.index)}"}>
        <span>{player.index}</span>
        <span>{player.name}</span>
        <span>{player.points}</span>
      </div>
    </div>

    <.button type="submit" phx-click="restart_game" style="padding: 3vw; width: 150px">
      new game
    </.button>
    """
  end

  # Result helpers
  defp get_position(enum) do
    Enum.map(
      enum,
      &Map.put_new(
        &1,
        :index,
        Enum.find_index(enum, fn p -> p.name == &1.name end) |> Kernel.+(1)
      )
    )
  end

  def div_selector(index) do
    cond do
      index == 1 -> "
      display: flex;
      background-color: #ebc12f; 
      height: 1.5em; 
      width: 80vw;
      text-align: center;
      color: black;
      border-radius: 1em;
      justify-content: space-evenly
      "
      index == 2 -> "
      display: flex;
      background-color: #b7cfce; 
      height: 1.5em; 
      width: 80vw;
      text-align: center;
      color: black;
      border-radius: 1em;
      justify-content: space-evenly
      "
      index == 3 -> "
      display: flex;
      background-color: #7d3b00; 
      height: 1.5em; 
      width: 80vw;
      text-align: center;
      border-radius: 1em;
      justify-content: space-evenly
      "
      rem(index, 2) == 1 -> "
      display: flex;
      background-color: #4e4e4e; 
      height: 1.5em; 
      width: 80vw;
      text-align: center;
      border-radius: 1em;
      justify-content: space-evenly
      "
      rem(index, 2) != 1 -> "
      display: flex;
      background-color: #2e2e2e; 
      height: 1.5em; 
      width: 80vw;
      text-align: center;
      border-radius: 1em;
      justify-content: space-evenly
      "
    end
  end
end
