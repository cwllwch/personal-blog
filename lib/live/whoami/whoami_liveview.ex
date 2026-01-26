defmodule PortalWeb.LiveStuff.Whoami do
  require Logger

  use PortalWeb, :live_view

  import Live.Whoami.Components
  alias PortalWeb.Presence
  alias Whoami.Helpers
  alias Whoami.Player
  alias Whoami.View
  alias Whoami

  @moduledoc """
  Orchestrates the game featured in Inglorious Bastards where
  everyone writes a famous person on a card then gets assigned 
  someone else's card. 

  Every time a new liveview with a cookie shows up to a lobby, a
  player is created from the cookie, and then stored in the socket. 
  This is because sessions store users and each socket hold the player, 
  and then sockets will insert users into the lobby or fetch them, 
  if the name matches.

  also some nomeclature weirdness: i decided to separate user and 
  player - user is just username in session, and player is the 
  entity associated with the lobby.
  """

  def mount(_params, session, socket) do
    context =
      session["user"]
      |> View.create_view()
      |> Map.from_struct()

    new_socket = assign(socket, context)

    {:ok, new_socket}
  end

  def handle_params(%{"lobby" => lobby}, _uri, socket) do
    case Helpers.find_player(socket.assigns.user, lobby) do
      {:ok, nil, free_spots} ->
        # The lobby exists but this player is not in it. adding player to the lobby if there are free spots
        Logger.info(message: "adding new player to lobby", user: socket.assigns.user)
        Helpers.put_into_lobby(socket, socket.assigns.user, lobby, free_spots)

      {:ok, player, free_spots} ->
        # This means the player is already in the lobby
        Logger.info("found player #{socket.assigns.user} in lobby #{inspect(lobby)}")
        Helpers.put_into_lobby(socket, player, lobby, free_spots)

      {:error, message} ->
        Logger.warning(message: "can't put user into lobby", error: message)

        new_socket =
          socket
          |> put_flash(:error, message)

        {:noreply, push_navigate(new_socket, to: ~p{/whoami})}
    end
  end

  def handle_params(_params, _uri, socket) do
    new_socket =
      assign(socket,
        loading: false,
        player: Player.create_player(socket.assigns.user)
      )

    {:noreply, new_socket}
  end

  def render(assigns) do
    ~H"""
    <p></p>
    <div class="field text-white">
      <%= cond do %>
        <% @loading == true -> %>
          <div class="justify-self-center justify-center">
            <.icon name="hero-arrow-path" class="animate-spin text-white" /> loading...
          </div>
        <% @stage == nil and @loading == false -> %>
          <.new_lobby
            question={"How many are playing, " <> @player.name <> "?"}
            button="create the lobby"
          />
        <% @stage == :waiting_room and @loading == false -> %>
          <.player_bar
            lobby_id={@lobby_id}
            self={@player}
            players={@players_in_lobby}
            disc_list={@disc_list}
            stage={@stage}
          />

          <.waiting_room
            lobby_id={@lobby_id}
            self={@player}
            can_start={@can_start}
          />
        <% @stage == :input_word and @loading == false -> %>
          <.player_bar
            lobby_id={@lobby_id}
            self={@player}
            players={@players_in_lobby}
            disc_list={@disc_list}
            stage={@stage}
          />

          <.input_word
            lobby_id={@lobby_id}
            self={@player}
            players={@players_in_lobby}
          />
        <% @stage == :waiting_for_words and @loading == false -> %>
          <.player_bar
            lobby_id={@lobby_id}
            self={@player}
            players={@players_in_lobby}
            disc_list={@disc_list}
            stage={@stage}
          />
          <div style="align-self: center; margin-top: 5em">
            <.icon name="hero-arrow-path" class="animate-spin text-white" /> waiting for others...
          </div>
        <% @stage == :versus_arena and @loading == false -> %>
          <.player_bar
            lobby_id={@lobby_id}
            self={@player}
            players={@players_in_lobby}
            disc_list={@disc_list}
            stage={@stage}
          />
          <.arena
            lobby_id={@lobby_id}
            self={@player}
            players={@players_in_lobby}
            word_in_play={@word_in_play}
            player_to_guess={@player_to_guess}
          />
        <% @stage == :answered and @loading == false -> %>
          waiting on everyone to answer as well...
      <% end %>
    </div>
    """
  end

  def handle_event("request_lobby", %{"player_count" => player_count}, socket) do
    send(self(), {:create_lobby, String.to_integer(player_count)})
    new_socket = assign(socket, :loading, true)
    {:noreply, new_socket}
  end

  def handle_event(
        "toggle_ready",
        _params,
        %{assigns: %{player: player, lobby_id: lobby_id}} = socket
      ) do
    new_player = %{player | ready: !player.ready}
    Helpers.update_presence(lobby_id, player.id, new_player)
    {:noreply, assign(socket, :player, new_player)}
  end

  def handle_event("enter_words", params, %{assigns: %{lobby_id: lobby, player: player}} = socket) do
    case Whoami.input_word(lobby, player.id, params) do
      {:ok} ->
        new_socket = assign(socket, stage: :waiting_for_words)
        {:noreply, new_socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("remove_player", %{"player" => player}, %{assigns: %{lobby_id: id}} = socket) do
    send(self(), {:remove_player, player})

    Helpers.broadcast({:see_yourself_out, player}, id)

    new_socket = assign(socket, loading: true)
    {:noreply, new_socket}
  end

  def handle_event("start_game", _params, %{assigns: %{lobby_id: id}} = socket) do
    Logger.debug(message: "starting the match", lobby: id)

    Helpers.broadcast({:update_stage, :input_word}, id)

    {:noreply, socket}
  end

  def handle_event(
        "answer_yes",
        _params,
        %{assigns: %{lobby_id: lobby, player: player, word_in_play: word}} = socket
      ) do
    send(self(), {:answer, lobby, :yes, player, word})
    {:noreply, assign(socket, stage: :answered)}
  end

  def handle_event(
        "answer_no",
        _params,
        %{assigns: %{lobby_id: lobby, player: player, word_in_play: word}} = socket
      ) do
    send(self(), {:answer, lobby, :no, player, word})
    {:noreply, assign(socket, stage: :answered)}
  end

  def handle_event(
        "answer_maybe",
        _params,
        %{assigns: %{lobby_id: lobby, player: player, word_in_play: word}} = socket
      ) do
    send(self(), {:answer, lobby, :maybe, player, word})
    {:noreply, assign(socket, stage: :answered)}
  end

  def handle_event(
        "illegal_question",
        _params,
        %{assigns: %{lobby_id: lobby, player: player, word_in_play: word}} = socket
      ) do
    send(self(), {:answer, lobby, :illegal, player, word})
    {:noreply, assign(socket, stage: :answered)}
  end

  def handle_event(
        "illegal_word",
        _params,
        %{assigns: %{lobby_id: lobby, player: player, word_in_play: word}} = socket
      ) do
    send(self(), {:answer, lobby, :word_trial, player, word})
    {:noreply, assign(socket, stage: :answered)}
  end

  def handle_info({:answer, lobby, :word_trial, player, word}, socket) do
    Whoami.initiate_trial(lobby, player, word)
    {:noreply, assign(socket, loading: true)}
  end

  def handle_info({:answer, lobby, answer, player, word}, socket) do
    Whoami.input_answer(lobby, answer, player, word)
    {:noreply, socket}
  end
  
  def handle_info({:create_lobby, player_count}, socket) do
    {:ok, _pid, lobby_id} = Whoami.create_lobby(player_count, socket.assigns.player)

    new_socket = Helpers.put_lobby_into_assigns(socket, lobby_id)

    {:noreply, push_patch(new_socket, to: ~p{/whoami?#{%{lobby: lobby_id}}})}
  end

  def handle_info({:fetch_players, lobby}, socket) do
    case Whoami.fetch_players(lobby) do
      {:ok, players, _count} ->
        new_players =
          Enum.reject(
            players,
            fn item ->
              item.name == socket.assigns.player.name
            end
          )

        {:noreply, assign(socket, players_in_lobby: new_players, loading: false)}

      {:error, message} ->
        Logger.info(message: message, lobby: lobby, player: socket.assigns.player)
        put_flash(socket, :info, message)
        {:noreply, push_patch(socket, to: ~p{/whoami})}
    end
  end

  def handle_info({:fetch_disc_list}, socket) do
    case Whoami.fetch_disc_list(socket.assigns.lobby_id) do
      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}

      list ->
        {:noreply, assign(socket, :disc_list, list)}
    end
  end

  def handle_info({:fetch_word_in_play}, socket) do
    Whoami.fetch_word_in_play(socket.assigns.lobby_id)
  end

  def handle_info({:fetch_stage, lobby}, socket) do
    case Whoami.fetch_stage(lobby) do
      {:ok, stage} ->
        send(self(), {:update_stage, stage})
        {:noreply, assign(socket, loading: true)}

      {:error, nil} ->
        {:noreply,
         assign(socket, loading: false, stage: nil)
         |> put_flash(:info, "Can't tell the stage of the game, go back to the start")}
    end
  end

  def handle_info({:update_stage, new_stage}, socket) do
    send(self(), {:update_interaction, System.system_time(:second)})

    if new_stage == :versus_arena do
      send(self(), {:fetch_next_word})
      {:noreply, assign(socket, stage: new_stage, loading: true)}
    else
      {:noreply, assign(socket, stage: new_stage, loading: false)}
    end
  end

  def handle_info({:add_player, lobby}, socket) do
    case Whoami.add_player(lobby, socket.assigns.player) do
      {:ok, players, _count} ->
        Logger.info(
          message: "added #{socket.assigns.player.name} to lobby",
          players: players,
          lobby: lobby
        )

        new_socket = put_flash(socket, :info, "You are now in lobby #{lobby}")
        {:noreply, new_socket}

      {:error, reason} ->
        Logger.warning(
          message: "unable to add #{socket.assigns.player.name} to lobby",
          lobby: lobby,
          error: reason
        )

        new_socket = socket |> put_flash(:info, reason)
        {:noreply, push_patch(new_socket, to: ~p{/whoami})}
    end
  end

  def handle_info({:can_start_toggle, status}, socket) do
    {:noreply, assign(socket, :can_start, status)}
  end

  def handle_info({:change_disc_list, new_list}, socket) do
    {:noreply, assign(socket, :disc_list, new_list)}
  end

  def handle_info({:fetch_next_word}, socket) do
    case Whoami.fetch_word_in_play(socket.assigns.lobby_id) do
      {:error, reason} ->
        Logger.info(
          message: "can't update the word for user",
          lobby: socket.assigns.lobby_id,
          reason: reason,
          player: socket.assigns.player.id
        )

        {:noreply, put_flash(socket, :error, "Couldn't get the word in play")}

      {word, player} ->
        # this player object is merely the id, so still need to fetch the whole player obj 
        # from socket before assigning it to the assigns field that will be passed to the 
        # component. I could also do this in the component, but it's easier here.
        new_socket =
          assign(
            socket,
            word_in_play: word,
            player_to_guess: Helpers.fill_with_player(socket, player),
            loading: false
          )

        {:noreply, new_socket}
    end
  end

  # Removes the player from the lobby state
  def handle_info({:remove_player, player}, socket) do
    case Whoami.remove_player(socket.assigns.lobby_id, player) do
      {:ok, players} ->
        Logger.info(
          message: "removed player from lobby",
          player: player,
          lobby: socket.assigns.lobby_id
        )

        new_socket =
          assign(
            socket,
            players_in_lobby: players,
            loading: false
          )
          |> put_flash(:info, "Kicked player #{player} from the lobby!")

        {:noreply, new_socket}
    end
  end

  # Removes the player liveview from the specified lobby.
  def handle_info(
        {:see_yourself_out, player},
        %{assigns: %{lobby_id: lobby, player: self}} = socket
      ) do
    list = List.flatten([player])

    Logger.debug(
      message: "leaving lobby",
      lobby: lobby,
      players_asked_to_leave: player,
      self: self.name
    )

    if self.name in list do
      Presence.untrack(self(), "lobby:#{lobby}", self.id)

      new_socket = put_flash(socket, :error, "you've been kicked ¯\\\_(ツ)_/¯ ")

      {:noreply, push_navigate(new_socket, to: ~p{/whoami})}
    else
      new_list = Enum.reject(socket.assigns.players_in_lobby, &(&1.name == player))
      {:noreply, assign(socket, :players_in_lobby, new_list)}
    end
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    new_socket =
      socket
      |> Helpers.remove_presences(diff.leaves)
      |> Helpers.add_presences(diff.joins)

    send(self(), {:update_interaction, System.system_time(:second)})

    {:noreply, new_socket}
  end

  def handle_info({:update_interaction, timestamp}, socket) do
    case Whoami.update_interaction(socket.assigns.lobby_id, timestamp) do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        Logger.info(message: "can't update last interaction", error: reason)
        {:noreply, socket}
    end
  end
end
