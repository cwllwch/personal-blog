defmodule Whoami.Main do
  require Logger
  alias Whoami.GameServer
  

  @moduledoc """
  The client for GameServer, primary way to interact with it from
  the liveview page.
  """

  def create_lobby(player_count, captain) do
    lobby_id = generate_id()
    args = {lobby_id, player_count, captain}
    {:ok, pid} = DynamicSupervisor.start_child(Lobby.Supervisor, {GameServer, args})

    Logger.info(
      message: "created lobby",
      lobby_pid: pid,
      lobby_id: lobby_id,
      captain: captain.name
    )
    {:ok, pid, lobby_id}
  end

  @doc """
  Adds a player to the state of the lobby. Note that 
  this is not the same as the presence itself. 
  """
  def add_player(lobby, player) when is_pid(lobby) do
    reply = GenServer.call(lobby, {:add_player, player})
    case reply do
      {:ok, players} ->
        {:ok, players}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def add_player(lobby, player) when is_binary(lobby) do 
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> add_player(pid, player)
      {:error, reason} -> {:error, reason}
    end
  end

  def remove_player(lobby, player) when is_pid(lobby) do
    reply = GenServer.call(lobby, {:remove_player, player})
    case reply do
      {:ok, players} ->
        {:ok, players}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def remove_player(lobby, player) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> remove_player(pid, player)
      {:error, reason} -> {:error, reason}
    end
  end
  
  def fetch_players(lobby) when is_integer(lobby), do: Integer.to_string(lobby) |> fetch_players()

  def fetch_players(lobby) when is_binary(lobby) do
    Logger.info([
      message: "checking out who's in a lobby", 
      lobby: lobby
    ])

    case Registry.lookup(Portal.LobbyRegistry, lobby) do
      [] -> {:error, "Could not find the lobby"}
      list -> 
        result = 
          List.first(list)
          |> elem(0)
          |> GenServer.call({:fetch_players})
        {:ok, result}
    end
  end


  # Helper functions
  def generate_id() do
    Stream.repeatedly(fn -> :rand.uniform(9) end)
    |> Enum.take(8)
    |> Enum.join("")
  end

  def get_pid_by_lid(lobby_id) do
    case Registry.lookup(Portal.LobbyRegistry, lobby_id) do
    [] -> 
      {:error, "Lobby not found"}
    
    list ->
      pid = List.first(list) |> elem(0)
      {:ok, pid}
    end
  end

  @doc """
  Returns a list of maps with all of the currently 
  running lobbies. This will be used to clean up the 
  processes later
  """
  def get_all_pids() do
    Registry.select(Portal.LobbyRegistry, [
    {
      {:"$1", :"$2", :"$3"}, 
      [{:==, :"$3", :lobby}], 
      [%{key: :"$1", pid: :"$2", val: :"$3"}]
      }
    ])
  end
end
