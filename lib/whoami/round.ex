defmodule Whoami.Round do
  alias Whoami.Player
  
  @moduledoc """
  Specifies a round and its related state. A round has 9 questions and one guess.
  A question will be a yes or no depending on the votes of the other participants. 
  At any point in the round, or, at the latest, upon exhausting the 9 questions, the 
  player will have to guess - and the guess will be correct or no depending on a myers
  difference comparison - so that if the word is Schwarzenegger there will be some leeway
  for honest typos. 
  """

  @enforce_keys [:answer]

  defstruct [
    round_id: 0,
    answer: nil,
    questions: [],
    votes_per_question: [],
    player: nil
  ]

  @type t :: %__MODULE__{
    round_id: non_neg_integer(),
    answer: String.t(),
    questions: list(),
    votes_per_question: list(),
    player: %Player{}
  }

  def create_round(player, word, prev_round) do
    %__MODULE__{
      round_id: prev_round + 1,
      answer: word,
      player: player
    }
  end
end
