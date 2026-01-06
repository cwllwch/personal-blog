defmodule Whoami.GameServer do
  require Logger
  use GenServer
  alias Whoami.LobbyStruct
  alias Phoenix.PubSub

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
      last_interaction: System.system_time(:second),
      stage: :waiting_room,
      ban_list: []
    }

    PubSub.subscribe(Portal.PubSub, "lobby:#{id}")

    Process.send_after(self(), {:time_to_live}, (60 * @ttl))

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
  def handle_call({:ban_check, player}, _from, state) do
    if player in state.ban_list do
      {:reply, {:banned}, state}  
    else
      {:reply, {:allowed}, state}  
    end
  end

  @impl true
  def handle_call({:fetch_players}, _from, state) do
    free_spots = state.player_count - length(state.players)
    {:reply, {state.players, free_spots}, state}
  end

  @impl true
  def handle_call({:fetch_stage}, _from, state) do
    {:reply, {:ok, state.stage}, state}
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
  def handle_info({:see_yourself_out, player}, state) do
    new_ban_list = [player] ++ state.ban_list
    {:noreply, %{state | ban_list: new_ban_list}}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, state) do
    new_state = %{state | players: handle_presences(diff, state.players)}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:toggle_status, player}, state) do
    new_list = 
    Enum.map(state.players, fn p -> 
      if p.name == player, do: %{p | ready: !p.ready}, else: p 
    end)
    {:noreply, %{state | players: new_list}}
  end

  @impl true
  def handle_info({:time_to_live}, state) do
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
        reply = {:error, message}
        {reply, state}
    end
  end

  defp maybe_add_player(new_player, state) when state.player_count <= length(state.players) do
    reply = {:error, 
      "Can't add player #{new_player} as it would exceed the max set amount of players"
      }
    {reply, state}
  end

  def already_here?(player, state) do
    ban_list = state.ban_list
    names = Enum.reduce(state.players, [], fn player, acc -> acc ++ [Map.get(player, :name)] end)
    cond  do
      player.name in ban_list -> {:error, "user has been banned from this lobby"}
      player.name not in names -> {:ok, "proceed"}
      true -> {:error, "user already in lobby"}
    end
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

  defp handle_presences(diff, players) do
    new_players = 
      players
      |> handle_joins(diff.joins)
      |> handle_leaves(diff.leaves)

    new_players
  end

  defp handle_joins(list, joins) when joins != %{}do
    simplified = simplify(joins) 

    Enum.map(list, fn player -> 
      if player.id in Map.keys(simplified) do
        Map.get(simplified, player.id)
      else 
        player
      end      
    end)
  end

  defp handle_joins(list, _joins), do: list

  defp handle_leaves(list, leaves) when leaves != %{} do
    simplified = simplify(leaves)

    Enum.reject(list, fn player ->
      player == Map.get(simplified, player.id)
    end)
    |> IO.inspect()
  end

  defp handle_leaves(list, _leaves), do: list 

  defp simplify(diff) do
    Enum.reduce(diff, %{}, fn {id, metas}, acc ->    # This is a rather convoluted way to get all joins, even 
      Map.put(acc, id, Map.get(metas, :metas))        # if there is a list with more than one sent. This will
    end)                                              # always create a list with the most recent state for each
    |> Enum.reduce(%{}, fn {id, list}, acc ->         # of the user ids - then just map it over user list and 
        latest =                                      # it's all good to be patched.
          Enum.sort_by(list, &(&1.timestamp), :desc)
          |> List.first() 

        Map.put_new(acc, id, latest.user)
      end)
  end
end

