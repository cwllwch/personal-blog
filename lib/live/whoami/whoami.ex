defmodule PortalWeb.LiveStuff.Whoami do
  require Logger

  use PortalWeb, :live_view
  
  import Live.Whoami.Components

  alias Phoenix.PubSub
  alias PortalWeb.Presence
  alias Whoami.Main, as: Lobby
  alias Whoami.Player

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
        loading: false,
        player: nil,
        user: session["user"],
        lobby_id: nil,
        players_in_lobby: [],
        full: false,
        in_lobby: false,
        link: nil
      )

    {:ok, new_socket}
  end

  def handle_params(%{"lobby" => lobby}, _uri, %{assigns: %{unwanted_here: lobby}} = socket) do
    new_socket = assign(
      socket,
      loading: false,
      in_lobby: false,
      player: create_player(socket.assigns.user),
      players_in_lobby: [],
      link: nil,
      unwanted_here: false
    )
    |> put_flash(:info, "You were removed from that lobby")

    {:noreply, new_socket}
  end
  
  def handle_params(%{"lobby" => lobby}, _uri, socket) do 
    topic = "lobby:#{lobby}"

    case find_player(socket.assigns.user, lobby) do
      {:ok, nil, free_spots} -> 
        # The lobby exists but this player is not in it. adding player to the lobby if there are free spots
        Logger.info([message: "adding new player to lobby", user: socket.assigns.user])
        put_into_lobby(socket, socket.assigns.user, lobby, free_spots)
    
      {:ok, player, _free_spots} ->
        # This means the player is already in the lobby
        Logger.debug("found player #{socket.assigns.user} in lobby #{inspect(lobby)}")
        new_socket = socket |> assign(
          loading: false,
          in_lobby: true,
          lobby_id: lobby,
          player: player,
          players_in_lobby: Presence.list(topic) |> flatten_presences(player.id),
          link: ~p{/whoami?#{%{lobby: lobby}}}
        )
        if connected?(new_socket) do
          newer_socket = track_presence(new_socket, topic)
          {:noreply, newer_socket}
         else
          {:noreply, new_socket}
        end
      {:error, message} ->
        Logger.warning([message: "unexpected error", error: message])
        new_socket = 
          socket
          |> put_flash(:error, message)
        {:noreply, push_navigate(new_socket, to: ~p{/whoami})}
    end
  end

  def handle_params(_params, _uri, socket) do
    new_socket = assign(socket, 
      loading: false,
      in_lobby: false,
      player: create_player(socket.assigns.user),
      players_in_lobby: [],
      link: nil,
      unwanted_here: false
    )

    {:noreply, new_socket}
  end


  def put_into_lobby(socket, user, lobby, free_spots) when free_spots > 0 do
    topic = "lobby:#{lobby}"
    player = create_player(user)
    presences = Presence.list(topic) |> flatten_presences(player.id)
    new_socket = 
      assign(socket,
        loading: false,
        lobby_id: lobby, 
        in_lobby: true,
        player: player,
        players_in_lobby: presences,
        link: ~p{/whoami?#{%{lobby: lobby}}}
      )
    if connected?(new_socket) do
      Lobby.add_player(lobby, player)
      new_socket = track_presence(new_socket, topic)
      {:noreply, new_socket}
    else
      {:noreply, new_socket}
    end
  end

  def put_into_lobby(socket, _user, _lobby, _free_spots) do
    new_socket = put_flash(socket, :error, "Lobby is already full!")
    {:noreply, push_navigate(new_socket, to: ~p{/whoami})}
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

        <% @in_lobby == false and @loading == false -> %>
          <.new_lobby
            question={"How many are playing, " <> @player.name <> "?"} 
            button="create the lobby"
          />

        <% @in_lobby == true and @loading == false -> %>
          <.waiting_room lobby_id={@lobby_id} self={@player} players={@players_in_lobby} />

      <% end %>
    </div>
    """
  end

  def handle_event("request_lobby", %{"player_count" => player_count}, socket) do
    send(self(), {:create_lobby, String.to_integer(player_count)})
    new_socket = assign(socket, :loading, true)
    {:noreply, new_socket}
  end

  def handle_event("fetch_players", _params, socket) do
    send(self(), {:fetch_players, socket.assigns.lobby_id})
    new_socket = assign(socket, :loading, true)
    {:noreply, new_socket}
  end

  def handle_event("remove_player", %{"player" => player}, socket) do
    send(self(), {:remove_player, player})
    PubSub.broadcast(Portal.PubSub, "lobby:#{socket.assigns.lobby_id}", {:see_yourself_out, player})
    new_socket = assign(socket, loading: true)
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
        players = Enum.filter(players,
          fn item -> 
            item.name == socket.assigns.player 
          end)
        |> Enum.reduce([], 
          fn p, acc -> 
            acc ++ [Map.get(p, :name)]
          end)

        {:noreply, assign(socket, players_in_lobby: players, loading: false)}
        
      {:error, message} -> 
        Logger.info([message: message, lobby: lobby, player: socket.assigns.player])
        put_flash(socket, :info, message)
        {:noreply, push_patch(socket, to: ~p{/whoami})}
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
        players: players,
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
      {:noreply, push_patch(new_socket, to: ~p{/whoami})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    new_socket = 
      socket 
      |> remove_presences(diff.leaves)
      |> add_presences(diff.joins)

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

  def remove_presences(socket, leaves) do
    ids_that_left = Map.keys(leaves)

    players = Enum.reject(socket.assigns.players_in_lobby, fn player -> player.user.id in ids_that_left end)

    assign(socket, players_in_lobby: players)
  end

  def add_presences(socket, joins) do
    non_self = Enum.reject(joins, fn {user, _metas} -> user == socket.assigns.player.id end)
    if non_self == [] do 
      socket 
    else 
      result =
       List.first(non_self)
        |> elem(1)
        |> Map.get(:metas)
        |> Enum.sort_by(&(&1.timestamp), {:desc, Date})
        |> Enum.dedup_by(&(&1.user.id))

      assign(socket, players_in_lobby: socket.assigns.players_in_lobby ++ result)
    end
  end

  def create_player(username) do
    %Player{
      name: username,
      id: Lobby.generate_id(),
      points: 0,
      wins: 0
    }
  end

  def find_player(username, lobby) do
    case Lobby.fetch_players(lobby) do
      {:ok, {users, free_spots}} -> 
        {:ok, Enum.filter(users, fn user -> user.name == username end) |> List.first(), free_spots}
      {:error, message} -> 
        Logger.info([message: "tried to find a lobby that doesn't exist", user: username])
        {:error, message}
    end
  end

  defp flatten_presences(presences, self_id) do
    Enum.reject(presences, fn {k, _v} -> k == self_id end)
    |> Enum.reduce([], 
      fn {_key, val}, acc -> 
        acc ++ [List.first(val.metas)] 
      end)
  end
  
  defp track_presence(socket, topic) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Portal.PubSub, topic)
      {:ok, _} = Presence.track(
        self(), 
        topic, 
        socket.assigns.player.id, 
        %{
          user: socket.assigns.player, 
          connected: true,
          timestamp: inspect(System.system_time(:second))
        }
      )
      Logger.info([message: "connected to topic", topic: topic, player: socket.assigns.player.name])
      socket
    else
      Logger.info([message: "socket not connected", topic: topic])
      socket
    end
  end
end
