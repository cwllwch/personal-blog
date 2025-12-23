defmodule Whoami.GameServer do
  require Logger
  use GenServer
  alias Whoami.LobbyStruct

  @moduledoc """
  The lobby itself, the processes that hold state and 
  get interacted with via the Main module, which acts as
  the Client for this server and also initiates new children
  under the dynamic supervisor.
  """

  @impl true
  def init({id, player_count, captain} = _args) do
    initial_state = %LobbyStruct{
      id: id,
      player_count: player_count,
      captain: captain,
      players: [captain]
    }

    {:ok, initial_state}
  end

  def start_link({lobby, _player_count, _captain} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(lobby))
  end

  def via_tuple(lobby) do
    {:via, Registry, {Portal.LobbyRegistry, lobby, :lobby}}
  end

  @impl true
  def handle_call({:add_player, new_player}, _from, state) do
    {reply, new_state} = maybe_add_player(new_player, state)
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call({:remove_player, player}, _from, state) do
    case remove_player(player, state) do
      {:ok, player_list} -> 
        reply = {:ok, player_list}
        new_state = %LobbyStruct{state | players: player_list}
        {:reply, reply, new_state}
      {:error, message} -> 
        {:reply, {:error, message}, state}
    end
  end

  @impl true
  def handle_call({:fetch_players}, _from, state) do
    free_spots = state.player_count - length(state.players)
    {:reply, {state.players, free_spots}, state}
  end

  defp maybe_add_player(new_player, state) when state.player_count > length(state.players) do
    case already_here?(new_player, state) do
      {:ok, "proceed"} -> 
        Logger.debug([message: "user not in lobby", player: new_player])
        reply = {:ok, state.players ++ [new_player]}
        {reply, %LobbyStruct{state | players: state.players ++ [new_player]}}
      {:error, message} -> 
        Logger.debug([message: message, player: new_player])
        reply = {:ok, state.players}
        {reply, state}
    end
  end

  defp maybe_add_player(new_player, state) when state.player_count <= length(state.players) do
    reply = {:error, 
      "Can't add player #{new_player} as it would exceed #{state.player_count}, the max set amount of players"
      }
    {reply, state}
  end

  def already_here?(player, state) do
    names = Enum.reduce(state.players, [], fn player, acc -> acc ++ [Map.get(player, :name)] end)
    if player.name not in names, do: {:ok, "proceed"}, else: {:error, "user already in lobby"}
  end

  def remove_player(player_to_del, state) do
    names = Enum.reduce(state.players, [], fn player, acc -> acc ++ [Map.get(player, :name)] end)
    
    if player_to_del in names do
      player_list = Enum.reject(state.players, fn player -> Map.get(player, :name) == player_to_del end)
      {:ok, player_list}
    else
      {:error, "Player is already not in the lobby!"}
    end
  end
end
