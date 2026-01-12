defmodule Whoami.Helpers do
  use PortalWeb, :live_view
  alias Whoami.Player
  alias Whoami.Main, as: Lobby
  alias PortalWeb.Presence
  alias Phoenix.PubSub
  require Logger
  @moduledoc """
  Helpers for the Whoami Liveview page. 
  These were originally in the liveview itself, but separated once that became too big
  """

  def put_into_lobby(socket, user, lobby, free_spots) when free_spots > 0 do
    topic = "lobby:#{lobby}"
    player = create_player(user)

    new_socket = 
      assign(socket,
        loading: true,
        lobby_id: lobby, 
        stage: fetch_stage(lobby),
        can_start: false,
        player: player,
        players_in_lobby: fetch_players(lobby),
        disc_list: fetch_disc_list(),
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

  def remove_presences(socket, _leaves) do
    send(self(), {:fetch_players, socket.assigns.lobby_id})
    socket
  end

  def add_presences(socket, joins) do
    player_list = 
      Enum.reduce(socket.assigns.players_in_lobby, [], fn player, acc -> 
        List.insert_at(acc, -1, player.id) 
      end)
    non_repeated = 
      Enum.reject(joins, fn {user, _metas} -> 
        user == socket.assigns.player.id || user in player_list 
      end)
    if non_repeated == [] do 
      socket 
    else
      new_joins = simplify(non_repeated) 
      |> Map.values()

      assign(socket, players_in_lobby: socket.assigns.players_in_lobby ++ new_joins)
    end
  end

  def create_player(username) do
    %Player{
      name: username,
      id: Lobby.generate_id(),
      points: 0,
      ready: false,
      wins: 0
    }
  end

  def fill_with_player(socket, player) do
    case Enum.filter(socket.assigns.players_in_lobby, fn p -> p.id == player end) do
      [] -> socket.assigns.player
      [player] -> player
    end
  end

  def fetch_players(lobby) do
    send(self(), {:fetch_players, lobby})
    []
  end

  def fetch_disc_list() do
    send(self(), {:fetch_disc_list})
    []
  end
  

  def fetch_stage(lobby) do
    send(self(), {:fetch_stage, lobby})
    nil
  end

  def find_player(username, lobby) when not is_tuple(username) do
    case Lobby.ban_check(username, lobby) do
      {:error, message} -> {:error, message}
      {:ok, _} -> find_player({:allowed, username}, lobby)
    end
  end
  
  def find_player({:allowed, username}, lobby) do
    case Lobby.fetch_players(lobby) do
      {:ok, users, free_spots} -> 
        {:ok, Enum.filter(users, fn user -> user.name == username end) |> List.first(), free_spots}
      {:error, message} -> 
        Logger.info([message: "can't find lobby", user: username])
        {:error, message}
    end
  end

  def track_presence(socket, topic) do
    if connected?(socket) do
      PubSub.subscribe(Portal.PubSub, topic)
      {:ok, _} = Presence.track(
        self(), 
        topic, 
        socket.assigns.player.id, 
        %{
          user: socket.assigns.player, 
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


  def simplify(diff) do
    # This is a rather convoluted way to get all joins, even 
    Enum.reduce(diff, %{}, fn {id, metas}, acc ->
      # if there is a list with more than one sent. This will
      Map.put(acc, id, Map.get(metas, :metas))
    end)

    # always create a list with the most recent state for each
    # of the user ids - then just map it over user list and 
    |> Enum.reduce(%{}, fn {id, list}, acc ->
      # it's all good to be patched.
      latest =
        Enum.sort_by(list, & &1.timestamp, :desc)
        |> List.first()

      Map.put_new(acc, id, latest.user)
    end)
  end
end
