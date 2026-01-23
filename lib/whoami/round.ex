defmodule Whoami.Round do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Specifies a round and its related state. A round has 9 questions and one guess.
  A question will be a yes or no depending on the votes of the other participants. 
  At any point in the round, or, at the latest, upon exhausting the 9 questions, the 
  player will have to guess - and the guess will be correct or no depending on a myers
  difference comparison - so that if the word is Schwarzenegger there will be some leeway
  for honest typos. 
  """

  @questions_per_round 10

  @primary_key false
  embedded_schema do
    field :round_id, :integer, default: 0
    field :answer, :string
    field :questions, {:array, :map}, default: []
    field :votes_per_question, :map, default: %{}
    field :guesser, :map
    field :players, {:array, :map}
  end

  @type t :: %__MODULE__{
          round_id: non_neg_integer(),
          answer: String.t(),
          questions: list(),
          votes_per_question: map(),
          guesser: map(),
          players: list()
        }

  def changeset(round, attrs) do
    round
    |> cast(attrs, [:round_id, :answer, :questions, :votes_per_question, :guesser, :players])
    |> validate_required([:answer])
    |> validate_vote_lists()
  end

  defp validate_vote_lists(changeset) do
    validate_change(
      changeset,
      :votes_per_question,
      fn :votes_per_question, votes ->
        if Enum.all?(votes, fn {_k, v} -> is_map(v) end) do
          []
        else
          [votes_per_question: "each vote must be a map"]
        end
      end
    )
  end

  def create_round(guesser, players, word, prev_round) do
    %__MODULE__{}
    |> changeset(%{
      round_id: prev_round + 1,
      answer: word,
      questions: gen_question_stubs(),
      guesser: guesser,
      players: players
    })
    |> apply_action!(:create)
  end

  def add_question(round, question) do
    round
    |> changeset(%{questions: round.questions ++ [question]})
    |> apply_action!(:update)
  end

  def add_vote(round, question, player, answer) do
    new_votes =
      Map.update(
        round.votes_per_question,
        question,
        %{player => answer},
        fn existing -> Map.put(existing, player, answer) end
      )

    round
    |> changeset(%{votes_per_question: new_votes})
    |> apply_action(:update)
  end

  def get_current_question(round) do
    non_empty = Enum.reject(round.questions, fn {_k, v} -> v == %{} end)
    if non_empty != [] do
      highest_key = Enum.sort(non_empty, :desc) |> List.first() |> elem(0)
      is_done = check_question_votes(highest_key, round)
    else
      1
    end
  end

  def check_question_votes(question, round) do
    votes = Map.get(round.votes_per_question, question)
    
  end

  defp gen_question_stubs() do
    Enum.map(1..@questions_per_round, fn x -> %{x => %{}} end)
  end
end
