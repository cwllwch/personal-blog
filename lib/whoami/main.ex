defmodule Whoami.Main do
  require Logger
  alias Whoami.GameServer

  @moduledoc """
  The client for GameServer, primary way to interact with it from
  the liveview page.
  """

  def create_lobby(player_count, captain) do
    lobby_id = generate_id()
    name = {:via, Registry, {Portal.LobbyRegistry, lobby_id}}
    args = {lobby_id, player_count, captain}
    {:ok, pid} = GenServer.start_link(GameServer, args, name: name)

    Logger.info(
      message: "created lobby",
      lobby_pid: pid,
      lobby_id: lobby_id,
      captain: captain.name
    )

    {:ok, pid, lobby_id}
  end

  def add_player(lobby, player) do
    reply = GenServer.call(lobby, {:add_player, player})

    case reply do
      {:ok, players} ->
        string = Enum.map_join(players, ", ", &Map.get(&1, :name))
        {:ok, "Now we have players: #{string} waiting in the lobby!"}

      {:error, reason} ->
        {:error, reason}
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
      IO.inspect(list)
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
end
