defmodule Whoami.Round do
  @moduledoc """
  Specifies a round and its related state. A round has 9 questions and one guess.
  A question will be a yes or no depending on the votes of the other participants. 
  At any point in the round, or, at the latest, upon exhausting the 9 questions, the 
  player will have to guess - and the guess will be correct or no depending on a myers
  difference comparison - so that if the word is Schwarzenegger there will be some leeway
  for honest typos. 
  """

  defstruct [
    :questions,
    :votes_per_question,
    :answer,
    :player
  ]
end
