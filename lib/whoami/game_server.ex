defmodule Whoami.GameServer do
  use GenServer
  alias Whoami.Lobby

  @moduledoc """
  Starts and orchestrates the game server. The 
  game consists of multiple processes: the server, 
  which holds state, and the processes assigned
  to each player, which will display the info 
  and options to each player.
  """

  @impl true
  def init({id, player_count, captain} = _args) when player_count > 1 do
    initial_state = %Lobby{
      id: id,
      player_count: player_count,
      captain: captain,
      players: [captain]
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:add_player, new_player}, _from, state) do
    {reply, new_state} = maybe_add_player(new_player, state)
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call({:fetch_players}, _from, state) do
    {:reply, state.players, state}
  end

  defp maybe_add_player(new_player, state) when state.player_count > length(state.players) do
reply = {:ok, state.players ++ [new_player]}
    new_state = %Lobby{state | players: state.players ++ [new_player]}
    {reply, new_state}
  end

  defp maybe_add_player(new_player, state) when state.player_count <= length(state.players) do
    reply = {:error, 
      "Can't add player #{new_player} as it would exceed #{state.player_count}, the max set amount of players"
      }
    {reply, state}
  end
end
