defmodule Whoami.GameServer do
  require Logger
  use GenServer
  alias Whoami.LobbyStruct
  alias Whoami.Round
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
    initial_state = LobbyStruct.create_lobby(id, player_count, captain)

    PubSub.subscribe(Portal.PubSub, "lobby:#{id}")

    Process.send_after(self(), {:time_to_live}, 60 * @ttl)

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
    {:reply, {:ok, state.players, free_spots}, state}
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
  def handle_call({:fetch_disc_list}, _from, state) do
    {:reply, {:ok, state.disc_list}, state}
  end

  @impl true
  def handle_call({:fetch_word_list}, _from, state) do
    {:reply, {:ok, state.word_map}, state}
  end

  @impl true
  def handle_call({:fetch_word_in_play}, _from, state) do
    player_to_guess = List.last(state.word_queue)
    {:reply, {:ok, state.word_in_play, player_to_guess}, state}
  end

  @impl true
  def handle_call({:set_next_word}, _from, state) do
    case get_next_word(state) do
      {:ok, new_state} -> {:reply, {:ok}, new_state}
      error -> {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_cast({:input_word, player, word}, state) do
    keys = Map.keys(state.word_map)

    if player in keys do
      Logger.info(message: "not inserting words", player: player, lobby: state.id)
      {:noreply, state}
    else
      new_state = %{state | word_map: Map.put_new(state.word_map, player, word)}
      send(self(), {:check_words_complete})
      Logger.debug(message: "inserted words", player: player, words: inspect(word))
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:interaction, timestamp}, state) do
    new_state = %{state | last_interaction: timestamp}

    Logger.debug(
      message: "updated interaction, server will keep alive for #{inspect(@ttl)} more minutes",
      timestamp: timestamp |> DateTime.from_unix() |> elem(1),
      lobby: state.id
    )

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:update_stage, :versus_arena}, state) do
    prev_round = get_round(state)
    player = state.word_queue |> List.last() # The current round already moved the in-turn player to last position in q by now
    {:noreply, %{state | stage: :versus_arena, round: Round.create_round(player, state.word_in_play, prev_round)}}
  end

  @impl true
  def handle_info({:update_stage, new_stage}, state) do
    {:noreply, %{state | stage: new_stage}}
  end

  # this is used to update the liveviews, handled here just to not generate an error
  def handle_info({:change_disc_list, _new_disc_list}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:add_to_disc_list, player}, state) do
    new_disc_list = [player] ++ state.disc_list

    PubSub.broadcast(Portal.PubSub, "lobby:#{state.id}", {:change_disc_list, new_disc_list})
    {:noreply, %{state | disc_list: new_disc_list}}
  end

  @impl true
  def handle_info({:remove_from_disc_list, player}, state) do
    new_disc_list =
      Enum.map(state.disc_list, fn id ->
        if id == player, do: [], else: id
      end)
      |> List.flatten()

    PubSub.broadcast(Portal.PubSub, "lobby:#{state.id}", {:change_disc_list, new_disc_list})
    {:noreply, %{state | disc_list: new_disc_list}}
  end

  @impl true
  def handle_info({:see_yourself_out, player}, state) do
    new_ban_list = [player] ++ state.ban_list
    {:noreply, %{state | ban_list: new_ban_list}}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, state) do
    new_state = %{state | players: handle_presences(diff, state.players)}
    if state.stage == :waiting_room, do: send(self(), {:can_start?})
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:can_start?}, state) do
    unready =
      Enum.reduce(state.players, [], fn player, acc ->
        if player.ready == false, do: List.insert_at(acc, -1, player.id), else: acc
      end)

    n = length(state.players)

    if unready != [] or n < state.player_count do
      Logger.info(message: "not ready to start yet", lobby: state.id)
      PubSub.broadcast(Portal.PubSub, "lobby:#{state.id}", {:can_start_toggle, false})
      {:noreply, state}
    else
      Logger.info(message: "ready to start!", lobby: state.id)
      PubSub.broadcast(Portal.PubSub, "lobby:#{state.id}", {:can_start_toggle, true})
      {:noreply, state}
    end
  end

  def handle_info({:can_start_toggle, _status}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:check_words_complete}, state) do
    players_in_word_list = Map.keys(state.word_map) |> Enum.sort()
    player_list = Enum.map(state.players, & &1.id) |> Enum.sort()

    if player_list == players_in_word_list do
      queue = players_in_word_list |> Enum.sort(:desc)

      new_state =
        Map.put(state, :word_queue, queue)
        |> get_next_word()

      PubSub.broadcast(Portal.PubSub, "lobby:#{state.id}", {:update_stage, :versus_arena})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:time_to_live}, state) do
    ttl = System.system_time(:second) - 60 * @ttl

    if state.last_interaction > ttl do
      Logger.info(
        [
          message: "keeping  alive",
          lid: state.id,
          last_interaction: state.last_interaction |> DateTime.from_unix() |> elem(1),
          cutoff: ttl |> DateTime.from_unix() |> elem(1),
          next_message_time:
            (System.system_time(:second) + 60 * @ttl) |> DateTime.from_unix() |> elem(1)
        ],
        ansi_color: :green
      )

      _ref = Process.send_after(self(), {:time_to_live}, 60_000 * @ttl)

      {:noreply, state}
    else
      Logger.info(
        [
          message: "killing myself",
          lid: state.id,
          last_interaction: state.last_interaction |> DateTime.from_unix() |> elem(1),
          cutoff: ttl |> DateTime.from_unix() |> elem(1),
          next_message_time:
            (System.system_time(:second) + 60 * @ttl) |> DateTime.from_unix() |> elem(1)
        ],
        ansi_color: :red
      )

      Whoami.destroy_lobby(state.id, state.players)
    end
  end
  
  def get_round(%LobbyStruct{round: list} = _state) do
    case list do
      [] -> 0
      not_empty -> 
        Enum.sort_by(not_empty, fn r -> r.round_id end, :desc)
        |> List.first()
        |> Map.get(:round_id)
    end
  end

  defp get_next_word(%LobbyStruct{word_map: word_map, word_queue: word_queue} = state) do
    {user, rest} = List.pop_at(word_queue, 0)

    # Makes a list of all the words that aren't made by the current user, rejects nil 
    # and then takes a random word from this list and outputs a list with exactly one word

    [next_word] =
      Enum.map(word_map, fn {k, v} -> if k != user, do: v end)
      |> Enum.reject(fn v -> v == nil end)
      |> List.flatten()
      |> Enum.take_random(1)

    [{key_to_update, list}] = Enum.filter(word_map, fn {_k, v} -> next_word in v end)

    new_list = Enum.reject(list, fn i -> i == next_word end)

    new_word_map = Map.replace(word_map, key_to_update, new_list)

    new_queue = rest ++ [user]

    Map.put(state, :word_queue, new_queue)
    |> Map.put(:word_map, new_word_map)
    |> Map.put(:word_in_play, next_word)
  end

  defp maybe_add_player(new_player, state) when state.player_count > length(state.players) do
    case already_here?(new_player, state) do
      {:ok, "proceed"} ->
        Logger.debug(message: "user not in lobby", player: new_player)
        reply = {:ok, state.players ++ [new_player]}
        {reply, %LobbyStruct{state | players: state.players ++ [new_player]}}

      {:error, message} ->
        Logger.debug(message: message, player: new_player)
        reply = {:error, message}
        {reply, state}
    end
  end

  defp maybe_add_player(new_player, state) when state.player_count <= length(state.players) do
    reply =
      {:error, "Can't add player #{new_player} as it would exceed the max set amount of players"}

    {reply, state}
  end

  def already_here?(player, state) do
    ban_list = state.ban_list
    names = Enum.reduce(state.players, [], fn player, acc -> acc ++ [Map.get(player, :name)] end)

    cond do
      player.name in ban_list -> {:error, "user has been banned from this lobby"}
      player.name not in names -> {:ok, "proceed"}
      true -> {:error, "user already in lobby"}
    end
  end

  def remove_player(player_to_del, state) do
    names = Enum.reduce(state.players, [], fn player, acc -> acc ++ [Map.get(player, :name)] end)

    if player_to_del in names do
      player_list =
        Enum.reject(state.players, fn player -> Map.get(player, :name) == player_to_del end)

      {:ok, player_list}
    else
      {:error, "Player is already not in the lobby!"}
    end
  end

  defp handle_presences(diff, players) do
    new_players =
      players
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)

    new_players
  end

  defp handle_joins(list, joins) when joins != %{} do
    simplified = simplify(joins)

    Enum.map(list, fn player ->
      if player.id in Map.keys(simplified) do
        remove_from_disc_list(player.id)
        Map.get(simplified, player.id)
      else
        player
      end
    end)
  end

  defp handle_joins(list, _joins), do: list

  defp handle_leaves(list, leaves) when leaves != %{} do
    simplified = simplify(leaves)

    Enum.map(list, fn player ->
      if player == Map.get(simplified, player.id) do
        add_to_disc_list(player.id)
        Map.put(player, :ready, false)
      else
        player
      end
    end)
  end

  defp handle_leaves(list, _leaves), do: list

  def add_to_disc_list(player_id) do
    send(self(), {:add_to_disc_list, player_id})
  end

  def remove_from_disc_list(player_id) do
    send(self(), {:remove_from_disc_list, player_id})
  end

  defp simplify(diff) do
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
