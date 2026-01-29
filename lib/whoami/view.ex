defmodule Whoami.View do
  alias Whoami.Player

  @moduledoc """
  This is a list of the variables to be manipulated by the liveview and server. 
  As the game grew, passing tons of key-value pairs inside assigns became more of a 
  hassle than a solution, so we are now only passing one struct and this struct gets changed 
  as it goes through the view.
  """

  @enforce_keys [:user]

  defstruct loading: true,
            player: nil,
            user: nil,
            lobby_id: nil,
            players_in_lobby: [],
            disc_list: [],
            full: false,
            link: nil,
            stage: nil,
            can_start: false,
            word_in_play: nil,
            player_to_guess: nil,
            answer_history: nil,
            answer: nil

  @type t :: %__MODULE__{
          loading: boolean(),
          player: %Player{},
          user: String.t(),
          lobby_id: non_neg_integer() | nil,
          players_in_lobby: list(),
          disc_list: list(),
          full: boolean(),
          link: String.t() | nil,
          stage: atom() | nil,
          can_start: boolean(),
          word_in_play: String.t() | nil,
          player_to_guess: %Player{} | nil,
          answer_history: map() | nil,
          answer: String.t() | nil
        }

  @spec create_view(String.t()) :: Whoami.View.t()
  def create_view(user) do
    %Whoami.View{user: user}
  end
end
