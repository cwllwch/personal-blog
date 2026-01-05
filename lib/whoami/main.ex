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

  @doc "Destroys the specified lobby. Requires the player list since this is also 
  ran for health checks in the lobby process itself, and it can't spawn calls to 
  itself - but it can pass the state player list. So just fetch the list if you 
  need this outside of the process."
  def destroy_lobby(lobby, list) when is_binary(lobby) do
    players = Enum.reduce(list, [], fn user, acc -> acc ++ [user.name] end)
    
    Phoenix.PubSub.broadcast(Portal.PubSub, "lobby:#{lobby}", {:see_yourself_out, players})

    {:ok, pid} = get_pid_by_lid(lobby)
    
    :ok = DynamicSupervisor.terminate_child(Lobby.Supervisor, pid)
    
    Logger.info([message: "killed lobby", lobby: lobby, players: players], aansi_color: :red)

    {:ok, "terminated"}
  end

  @doc """
  Updates the last_interaction in the server state.
  If the server remains uncontacted for too long, it will kill
  itself so as to not have forever-running processes
  """
  def update_interaction(lobby, timestamp) when is_pid(lobby) do
    GenServer.cast(lobby, {:interaction, timestamp})
  end

  def update_interaction(lobby, timestamp) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> update_interaction(pid, timestamp)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Adds a player to the state of the lobby. Note that this is not the same as the presence itself."
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

  def fetch_stage(lobby) do
    {:ok, pid} = get_pid_by_lid(lobby)
    case GenServer.call(pid, {:fetch_stage}) do
      {:ok, stage} -> 
        {:ok, stage}
      {:error, reason} -> 
        Logger.warning([
          message: "stage unavailable",
          lobby: lobby,
          reason: reason
        ])
        {:error, nil}
    end
  end

  def fetch_captain(lobby) do
    {:ok, pid} = get_pid_by_lid(lobby)
    case GenServer.call(pid, {:fetch_captain}) do
      {:ok, captain} -> 
        {:ok, captain}
      {:error, reason} -> 
        Logger.warning([
          message: "can't find captain",
          error: reason,
          lobby: lobby
        ])
        {:error, reason}
    end
  end

  def ban_check(username, lobby) do
    {:ok, pid} = get_pid_by_lid(lobby)
    case GenServer.call(pid, {:ban_check, username}) do
      {:banned} -> {:error, "You've been banned from this lobby"}
      {:allowed} -> {:ok, "Welcome!"}
    end
  end


  # Helper functions
  def generate_id() do
    Stream.repeatedly(fn -> :rand.uniform(9) end)
    |> Enum.take(8)
    |> Enum.join("")
  end

  @doc "Returns the process pid for the specified lobby by looking into the registry."
  def get_pid_by_lid(lobby_id) when is_binary(lobby_id) do
    case Registry.lookup(Portal.LobbyRegistry, lobby_id) do
    [] -> 
      {:error, "Lobby not found"}
    
    list ->
      pid = List.first(list) |> elem(0)
      {:ok, pid}
    end
  end

  def get_pid_by_lid(lobby_id) when is_integer(lobby_id), do: Integer.to_string(lobby_id) |>  get_pid_by_lid()
end
