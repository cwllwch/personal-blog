defmodule Whoami.Helpers do
  alias Phoenix.PubSub
  alias PortalWeb.Presence
  alias Whoami.Main
  alias Whoami.Player
  require Logger
  use PortalWeb, :live_view

  @moduledoc """
  Helpers for the Whoami Liveview page. 
  These were originally in the liveview itself, but separated once that became too big
  """

  @doc """
  Wraps PubSub broadcast becuase the PubSub itself is always the same, the topic and message
  are the bits that differ all the time. Makes the liveview cleaner
  """
  @spec broadcast(tuple(), String.t()) :: :ok | {:error, term()}
  def broadcast(message, lobby) do
    PubSub.broadcast(
      Portal.PubSub,
      "lobby:#{lobby}",
      message
    )
  end

  @doc """
  Puts the player in the lobby if player is a struct, or creates the struct if 
  the player is a binary. Returns the same as def handle_params/3 would.
  """
  def put_into_lobby(socket, player, lobby, _free_spots) when is_struct(player) do
    topic = "lobby:#{lobby}"

    new_socket =
      assign(socket,
        lobby_id: lobby,
        stage: fetch_stage(lobby),
        player: player,
        players_in_lobby: fetch_players(lobby),
        disc_list: fetch_disc_list(),
        link: ~p{/whoami?#{%{lobby: lobby}}}
      )

    if connected?(new_socket) do
      new_socket = track_presence(new_socket, topic)
      {:noreply, new_socket}
    else
      {:noreply, new_socket}
    end
  end

  def put_into_lobby(socket, player, lobby, free_spots)
      when free_spots > 0 and is_binary(player) do
    topic = "lobby:#{lobby}"
    player = Player.create_player(player)

    new_socket =
      assign(socket,
        lobby_id: lobby,
        stage: fetch_stage(lobby),
        player: player,
        players_in_lobby: fetch_players(lobby),
        disc_list: fetch_disc_list(),
        link: ~p{/whoami?#{%{lobby: lobby}}}
      )

    if connected?(new_socket) do
      Main.add_player(lobby, player)
      new_socket = track_presence(new_socket, topic)
      {:noreply, new_socket}
    else
      {:noreply, new_socket}
    end
  end

  def put_into_lobby(socket, _user, _lobby, _free_spots) do
    new_socket = put_flash(socket, :error, "This lobby is already full!")
    Process.send_after(self(), :clear_flash, 10_000)
    {:noreply, push_patch(new_socket, to: ~p{/whoami})}
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
      new_joins =
        simplify(non_repeated)
        |> Map.values()

      assign(socket, players_in_lobby: socket.assigns.players_in_lobby ++ new_joins)
    end
  end

  def put_lobby_into_assigns(%{assigns: map} = socket, lobby_id) do
    link = ~p{/whoami?#{%{lobby: lobby_id}}}

    new_assigns =
      map
      |> Map.put(:loading, false)
      |> Map.put(:lobby_id, lobby_id)
      |> Map.put(:link, link)
      |> Map.put(:in_lobby, true)

    %{socket | assigns: new_assigns}
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

  def fetch_disc_list do
    send(self(), {:fetch_disc_list})
    []
  end

  def fetch_stage(lobby) do
    send(self(), {:fetch_stage, lobby})
    nil
  end

  def find_player(username, lobby) when not is_tuple(username) do
    case Main.ban_check(username, lobby) do
      {:error, message} -> {:error, message}
      {:ok, _} -> find_player({:allowed, username}, lobby)
    end
  end

  def find_player({:allowed, username}, lobby) do
    case Main.fetch_players(lobby) do
      {:ok, users, free_spots} ->
        {:ok, Enum.filter(users, fn user -> user.name == username end) |> List.first(),
         free_spots}

      {:error, message} ->
        Logger.info(message: "can't find lobby", user: username)
        {:error, message}
    end
  end

  def track_presence(socket, topic) do
    if connected?(socket) do
      PubSub.subscribe(Portal.PubSub, topic)

      {:ok, _} =
        Presence.track(
          self(),
          topic,
          socket.assigns.player.id,
          %{
            user: socket.assigns.player,
            timestamp: inspect(System.system_time(:second))
          }
        )

      Logger.info(message: "connected to topic", topic: topic, player: socket.assigns.player.name)
      socket
    else
      Logger.info(message: "socket not connected", topic: topic)
      socket
    end
  end

  def update_players(players, %{assigns: %{player: player}} = socket) do
    new_players =
      Enum.reject(
        players,
        fn item ->
          item.name == socket.assigns.player.name
        end
      )

    [server_self] = Enum.filter(players, &(&1.id == player.id))

    if player == server_self do
      assign(
        socket,
        player: player,
        players_in_lobby: new_players
      )
    else
      assign(
        socket,
        player: server_self,
        players_in_lobby: new_players
      )
    end
  end

  def update_presence(lobby_id, player_id, new_player) do
    {:ok, _} =
      Presence.update(
        self(),
        "lobby:#{lobby_id}",
        player_id,
        fn meta ->
          %{meta | user: new_player}
        end
      )
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

  def sanitize_word(word) when is_binary(word) do
    String.trim(word)
  catch
    e -> {:error, inspect(e)}
  end

  def sanitize_word(word) when not is_binary(word) do
    {:error, "not a string"}
  end
end
