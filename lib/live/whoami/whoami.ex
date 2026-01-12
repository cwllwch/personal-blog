defmodule PortalWeb.LiveStuff.Whoami do
  require Logger

  use PortalWeb, :live_view
  
  import Live.Whoami.Components
  alias Whoami.Helpers
  alias Phoenix.PubSub
  alias PortalWeb.Presence
  alias Whoami.Main, as: Lobby

  @moduledoc """
  Orchestrates the game featured in Inglorious Bastards where
  everyone writes a famous person on a card then gets assigned 
  someone else's card. 
  Every time a new liveview with a cookie shows up to a lobby, a
  user is created in the session, and then stored in the socket. 
  This is because sessions store usernames and each socket a user, 
  and then sockets will insert users into the lobby.

  also some nomeclature weirdness: i decided to separate user and 
  player - user is just username in session, and player is the 
  entity associated with the lobby.
  """

  def mount(_params, session, socket) do
    new_socket = 
      socket
      |> assign(
        page_title: "who am i",
        loading: true,
        player: nil,
        user: session["user"],
        lobby_id: nil,
        players_in_lobby: [],
        full: false,
        link: nil,
        stage: nil,
        word_in_play: nil,
        player_to_guess: nil
      )

    {:ok, new_socket}
  end

  def handle_params(%{"lobby" => lobby}, _uri, %{assigns: %{unwanted_here: lobby}} = socket) do
    new_socket = assign(
      socket,
      loading: false,
      players_in_lobby: [],
      unwanted_here: lobby,
      stage: nil
    )
    |> put_flash(:info, "You were removed from that lobby")

    {:noreply, new_socket}
  end
  
  def handle_params(%{"lobby" => lobby}, _uri, socket) do 
    topic = "lobby:#{lobby}"

    case Helpers.find_player(socket.assigns.user, lobby) do
      {:ok, nil, free_spots} -> 
        # The lobby exists but this player is not in it. adding player to the lobby if there are free spots
        Logger.info([message: "adding new player to lobby", user: socket.assigns.user])
        Helpers.put_into_lobby(socket, socket.assigns.user, lobby, free_spots)
    
      {:ok, player, _free_spots} ->
        # This means the player is already in the lobby
        Logger.debug("found player #{socket.assigns.user} in lobby #{inspect(lobby)}")
        new_socket = socket |> assign(
          loading: true,
          stage: Helpers.fetch_stage(lobby),
          ready: false,
          lobby_id: lobby,
          player: player,
          players_in_lobby: Helpers.fetch_players(lobby),
          can_start: false,
          disc_list: Helpers.fetch_disc_list(),
          link: ~p{/whoami?#{%{lobby: lobby}}}
        )
        if connected?(new_socket) do
          newer_socket = Helpers.track_presence(new_socket, topic)
          {:noreply, newer_socket}
         else
          {:noreply, new_socket}
        end
      {:error, message} ->
        Logger.warning([message: "can't put user into lobby", error: message])
        new_socket = 
          socket
          |> put_flash(:error, message)
        {:noreply, push_navigate(new_socket, to: ~p{/whoami})}
    end
  end

  def handle_params(_params, _uri, socket) do
    new_socket = assign(socket, 
      loading: false,
      player: Helpers.create_player(socket.assigns.user),
      players_in_lobby: [],
      link: nil,
      unwanted_here: false
    )

    {:noreply, new_socket}
  end
  
  def render(assigns) do
    ~H"""
    <p></p>
    <div class="field">
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
      <% end %>
    </div>
    """
  end

  def handle_event("request_lobby", %{"player_count" => player_count}, socket) do
    send(self(), {:create_lobby, String.to_integer(player_count)})
    new_socket = assign(socket, :loading, true)
    {:noreply, new_socket}
  end

  def handle_event("toggle_ready", %{"value" => _player}, socket) do
    new_player = %{socket.assigns.player | ready: !socket.assigns.player.ready}
    {:ok, _} = 
    Presence.update(
      self(),
      "lobby:#{socket.assigns.lobby_id}",
      socket.assigns.player.id,
      fn meta ->
        %{meta | user: new_player}
      end
    )
    {:noreply, assign(socket, :player, new_player)}
  end

  def handle_event("remove_player", %{"player" => player}, socket) do
    send(self(), {:remove_player, player})
    PubSub.broadcast(Portal.PubSub, "lobby:#{socket.assigns.lobby_id}", {:see_yourself_out, player})
    new_socket = assign(socket, loading: true)
    {:noreply, new_socket}
  end 

  def handle_event("start_game", _params, socket) do
    Logger.debug([message: "starting the match", lobby: socket.assigns.lobby_id])
    PubSub.broadcast(Portal.PubSub, "lobby:#{socket.assigns.lobby_id}", {:update_stage, :input_word})
    {:noreply, socket}
  end

  
  def handle_event("enter_words", %{"word_1" => word_1, "word_2" => word_2, "word_3" => word_3}, socket) do
    words = [word_1, word_2, word_3]
    Lobby.input_word(socket.assigns.lobby_id, socket.assigns.player.id, words)
    new_socket = assign(socket, stage: :waiting_for_words)
    {:noreply, new_socket}
  end
  
  def handle_event("enter_words", %{"word_1" => word_1, "word_2" => word_2}, socket) do
    words = [word_1, word_2]
    Lobby.input_word(socket.assigns.lobby_id, socket.assigns.player.id, words)
    new_socket = assign(socket, stage: :waiting_for_words)
    {:noreply, new_socket}
  end

  def handle_event("enter_words", %{"word_1" => word_1}, socket) do
    Lobby.input_word(socket.assigns.lobby_id, socket.assigns.player.id, word_1)
    new_socket = assign(socket, stage: :waiting_for_words)
    {:noreply, new_socket}
  end

  def handle_info({:create_lobby, player_count}, socket) do
    {:ok, _pid, lobby_id} = Lobby.create_lobby(player_count, socket.assigns.player)

    link = ~p{/whoami?#{%{lobby: lobby_id}}}

    new_socket =
      assign(socket, :loading, false)
      |> assign(:lobby_id, lobby_id)
      |> assign(:link, link)
      |> assign(:in_lobby, true)

    {:noreply, push_patch(new_socket, to: link)}
  end

  def handle_info({:fetch_players, lobby}, socket) do
      case Lobby.fetch_players(lobby) do
      {:ok, players, _count} -> 

        new_players = 
        Enum.reject(players,
          fn item -> 
            item.name == socket.assigns.player.name 
          end)

        {:noreply, assign(socket, players_in_lobby: new_players, loading: false)}
        
      {:error, message} -> 
        Logger.info([message: message, lobby: lobby, player: socket.assigns.player])
        put_flash(socket, :info, message)
        {:noreply, push_patch(socket, to: ~p{/whoami})}
    end
  end

  def handle_info({:fetch_disc_list}, socket) do
    case Lobby.fetch_disc_list(socket.assigns.lobby_id) do
      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
      list -> 
        new_socket = assign(
          socket,
          :disc_list,
          list
        )
        {:noreply, new_socket}
    end
  end

  def handle_info({:fetch_word_in_play}, socket) do
    Lobby.fetch_word_in_play(socket.assigns.lobby_id)
  end

  def handle_info({:fetch_stage, lobby}, socket) do
    case Lobby.fetch_stage(lobby) do
      {:ok, stage} ->
        send(self(), {:update_stage, stage})
        {:noreply, assign(socket, loading: true)}
      {:error, nil} ->
        {:noreply, 
          assign(socket, loading: false, stage: nil)
          |> put_flash(:info, "Can't tell the stage of the game, go back to the start")
        }
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
    case Lobby.add_player(lobby, socket.assigns.player) do
      {:ok, players, _count} -> 
        Logger.info([
          message: "added #{socket.assigns.player.name} to lobby", 
          players: players, 
          lobby: lobby
       ])
        new_socket = put_flash(socket, :info, "You are now in lobby #{lobby}")
        {:noreply, new_socket}
      {:error, reason} ->
        Logger.warning([message: "unable to add #{socket.assigns.player.name} to lobby", lobby: lobby, error: reason])
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
    case Lobby.fetch_word_in_play(socket.assigns.lobby_id) do
      {:error, reason} -> 
        Logger.info([
          message: "can't update the word for user", 
          lobby: socket.assigns.lobby_id,
          reason: reason,
          player: socket.assigns.player.id
        ])
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
    case Lobby.remove_player(socket.assigns.lobby_id, player) do
    {:ok, players} -> 
      Logger.info([
        message: "removed player from lobby",
        player: player,
        lobby: socket.assigns.lobby_id
      ])
      new_socket = assign(
        socket, 
        players_in_lobby: players,
        loading: false
      ) 
      |> put_flash(:info, "Kicked player #{player} from the lobby!")
      {:noreply, new_socket}
    end
  end

  # Removes the player liveview from the specified lobby.
  def handle_info({:see_yourself_out, player}, socket) do
    self = socket.assigns.player.name
    list = List.flatten([player])
    Logger.debug([
      message: "leaving lobby", 
      lobby: socket.assigns.lobby_id, 
      players_asked_to_leave: player,
      self: self
    ])

    if self in list do
      Presence.untrack(self(), "lobby:#{socket.assigns.lobby_id}", socket.assigns.player.id)
      new_socket = assign(socket,
        unwanted_here: socket.assigns.lobby_id
      )
      |> put_flash(:error, "you've been kicked ¯\\\_(ツ)_/¯ ")
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
    case Lobby.update_interaction(socket.assigns.lobby_id, timestamp) do
    :ok -> {:noreply, socket}
    {:error, reason} -> 
      Logger.info([message: "can't update last interaction", error: reason])
      {:noreply, socket}
    end
  end
end
