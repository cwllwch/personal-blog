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
    :word_map,
    :word_queue,
    :round
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
          word_map: map(),
          word_queue: list(String.t()) | [],
          round: list(Whoami.Round.t()) | []
        }

  def create_lobby(id, player_count, captain) do
    %__MODULE__{
      id: id,
      player_count: player_count,
      captain: captain,
      players: [captain],
      last_interaction: System.system_time(:second),
      stage: :waiting_room,
      ban_list: [],
      disc_list: [],
      word_in_play: nil,
      word_map: %{},
      word_queue: [],
      round: []
    }
  end
end
