defmodule Whoami do
  require Logger
  alias Whoami.Helpers
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

    Logger.info([message: "killed lobby", lobby: lobby, players: players], ansi_color: :magenta)

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

  def input_word(lobby, player, word) when is_pid(lobby) do
    word_list = Map.values(word) |> Enum.reject(fn i -> i == nil end)

    case Helpers.validate_words(word_list) do
      {:ok} ->
        GenServer.cast(lobby, {:input_word, player, word_list})
        {:ok}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def input_word(lobby, player, word) when is_binary(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> input_word(pid, player, word)
      {:error, reason} -> {:error, reason}
    end
  end

  def input_answer(lobby, answer, player, word) when is_pid(lobby) do
    GenServer.cast(lobby, {:answer, answer, player, word})
  end

  def input_answer(lobby, answer, player, word) when is_binary(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> input_answer(pid, answer, player, word)
      {:error, reason} -> {:error, reason}
    end
  end

  def initiate_trial(lobby, player, word) when is_pid(lobby) do
    Logger.info("Trial of word #{word} initiated by #{player.name}!")
  end

  def initiate_trial(lobby, player, word) when is_binary(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> initiate_trial(pid, player, word)
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

  def fetch_players(lobby) when is_pid(lobby) do
    GenServer.call(lobby, {:fetch_players})
  end

  def fetch_players(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> fetch_players(pid)
      {:error, message} -> {:error, message}
    end
  end

  def fetch_stage(lobby) when is_pid(lobby) do
    case GenServer.call(lobby, {:fetch_stage}) do
      {:ok, stage} ->
        {:ok, stage}

      {:error, reason} ->
        Logger.warning(
          message: "stage unavailable",
          lobby: lobby,
          reason: reason
        )

        {:error, nil}
    end
  end

  def fetch_stage(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> fetch_stage(pid)
      {:error, message} -> {:error, message}
    end
  end

  def fetch_captain(lobby) when is_pid(lobby) do
    case GenServer.call(lobby, {:fetch_captain}) do
      {:ok, captain} ->
        {:ok, captain}

      {:error, reason} ->
        Logger.warning(
          message: "can't find captain",
          error: reason,
          lobby: lobby
        )

        {:error, reason}
    end
  end

  def fetch_captain(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> fetch_captain(pid)
      {:error, message} -> {:error, message}
    end
  end

  def fetch_word_list(lobby) when is_pid(lobby) do
    case GenServer.call(lobby, {:fetch_word_list}) do
      {:ok, map} -> map
      any -> {:error, "Unexpected response: #{inspect(any)}"}
    end
  end

  def fetch_word_list(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> fetch_word_list(pid)
      {:error, message} -> {:error, message}
    end
  end

  def fetch_word_in_play(lobby) when is_pid(lobby) do
    case GenServer.call(lobby, {:fetch_word_in_play}) do
      {:ok, word, player} -> {word, player}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_word_in_play(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> fetch_word_in_play(pid)
      {:error, message} -> {:error, message}
    end
  end

  def fetch_disc_list(lobby) when is_pid(lobby) do
    case GenServer.call(lobby, {:fetch_disc_list}) do
      {:ok, list} -> list
      any -> {:error, "Unexpected response: #{inspect(any)}"}
    end
  end

  def fetch_disc_list(lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> fetch_disc_list(pid)
      {:error, message} -> {:error, message}
    end
  end

  def send_guess(word, lobby) when is_pid(lobby) do 
    case GenServer.call(lobby, {:guess, word}) do
      {:ok, :correct} -> {:ok, :correct}
      {:ok, :close} -> {:ok, :close}
      {:ok, :wrong} -> {:ok, :wrong}
      {:error, reason} -> {:error, reason}
    end
  end

  def send_guess(word, lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> send_guess(word, pid)
      {:error, message} -> {:error, message}
    end
  end

  def ban_check(username, lobby) when is_pid(lobby) do
    case GenServer.call(lobby, {:ban_check, username}) do
      {:banned} -> {:error, "You've been banned from this lobby"}
      {:allowed} -> {:ok, "Welcome!"}
    end
  end

  def ban_check(username, lobby) do
    case get_pid_by_lid(lobby) do
      {:ok, pid} -> ban_check(username, pid)
      {:error, message} -> {:error, message}
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

  def get_pid_by_lid(lobby_id) when is_integer(lobby_id),
    do: Integer.to_string(lobby_id) |> get_pid_by_lid()
end
