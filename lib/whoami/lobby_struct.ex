defmodule Whoami.LobbyStruct do
  @moduledoc """
  Defines the struct for a lobby
  """

  defstruct [
    :id,
    :player_count,
    :captain,
    :players,
    :last_interaction,
    :stage,
    :ban_list,
    :disc_list,
    :word_in_play,
    :author,
    :word_map,
    :word_queue,
    :round,
    :restart_votes
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          player_count: non_neg_integer(),
          captain: Whoami.Player.t(),
          players: list(Whoami.Player.t()),
          last_interaction: non_neg_integer(),
          stage: atom(),
          ban_list: list(String.t()),
          disc_list: list(String.t()),
          word_in_play: String.t() | nil,
          author: String.t() | nil,
          word_map: map(),
          word_queue: list(String.t()) | [],
          round: list(Whoami.Round.t()) | [],
          restart_votes: list()
        }

  def create_lobby(id, player_count, captain) do
    %__MODULE__{
      id: id,
      player_count: player_count,
      captain: captain,
      players: [captain],
      last_interaction: System.system_time(:second),
      stage: :waiting_room,
      author: nil,
      ban_list: [],
      disc_list: [],
      word_in_play: nil,
      word_map: %{},
      word_queue: [],
      round: [],
      restart_votes: []
    }
  end

  def restart(lobby) do
    winner =
      Enum.sort_by(lobby.players, & &1.points, :desc)
      |> List.first()

    new_players =
      lobby.players
      |> Enum.map(&Map.put(&1, :points, 0))
      |> Enum.map(&Map.put(&1, :ready, false))
      |> Enum.map(
        &if &1.id == winner.id, do: Map.update!(&1, :wins, fn val -> val + 1 end), else: &1
      )

    %__MODULE__{
      lobby
      | players: new_players,
        author: nil,
        word_in_play: nil,
        word_map: %{},
        round: [],
        restart_votes: [],
        word_queue: [],
        stage: :waiting_room,
        last_interaction: System.system_time(:second)
    }
  end
end
