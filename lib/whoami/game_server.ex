defmodule Whoami.GameServer do
  require Logger
  use GenServer
  alias Whoami.LobbyStruct

  @moduledoc """
  The lobby itself, the processes that hold state and 
  get interacted with via the Main module, which acts as
  the Client for this server and also initiates new children
  under the dynamic supervisor.

  ttl is set in minutes
  """

  @ttl 15

  @impl true
  def init({id, player_count, captain} = _args) do
    initial_state = %LobbyStruct{
      id: id,
      player_count: player_count,
      captain: captain,
      players: [captain],
      last_interaction: System.system_time(:second)
    }

    Process.send_after(self(), {:time_to_live}, (60 * @ttl))
    |> IO.inspect()

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

  @impl true
  def handle_call({:fetch_captain}, _from, state) do
    {:reply, {:ok, state.captain}, state}
  end
  
  @impl true
  def handle_cast({:interaction, timestamp}, state) do
    new_state = %{state | last_interaction: timestamp}
    Logger.debug([
      message: "updated interaction, server will keep alive for #{inspect(@ttl)} more minutes", 
      timestamp: timestamp |> DateTime.from_unix() |> elem(1),
      lobby: state.id
    ])
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:time_to_live}, state) do
    IO.inspect(state, pretty: true)
    ttl = System.system_time(:second) - (60 * @ttl)
    if state.last_interaction > ttl do
      Logger.info([
        message: "keeping  alive", 
        lid: state.id, 
        last_interaction: state.last_interaction |> DateTime.from_unix() |> elem(1), 
        cutoff: ttl |> DateTime.from_unix() |> elem(1),
        next_message_time: System.system_time(:second) + (60 * @ttl) |> DateTime.from_unix() |> elem(1)
      ], ansi_color: :green)
      
      _ref = Process.send_after(self(), {:time_to_live}, (60000 * @ttl))
      
      {:noreply, state}
    else
      Logger.info([
        message: "killing myself", 
        lid: state.id, 
        last_interaction: state.last_interaction |> DateTime.from_unix() |> elem(1), 
        cutoff: ttl |> DateTime.from_unix() |> elem(1),
        next_message_time: System.system_time(:second) + (60 * @ttl) |> DateTime.from_unix() |> elem(1)
      ], ansi_color: :red)

      Whoami.Main.destroy_lobby(state.id, state.players)
    end
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
