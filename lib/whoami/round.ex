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

  def add_vote(round, player, answer) do
    # Gets the question list, finds the lowest empty one, then extracts the keys of the question to add the answer
    question =
      round.questions
      |> Enum.filter(fn q -> Map.values(q) |> hd() == %{} end)
      |> Enum.sort(:asc)
      |> hd()
      |> Map.keys()
      |> hd()

    new_votes =
      Map.update(
        round.votes_per_question,
        question,
        %{player.id => answer},
        fn existing -> Map.put(existing, player.id, answer) end
      )

    round
    |> changeset(%{votes_per_question: new_votes})
    |> apply_action(:update)
  end

  
  def evaluate_votes(%{votes_per_question: votes, players: players} = round) do
    threshold = length(players) |> Kernel.-(1) |> Kernel.*(0.7)
    
    {yes, no, maybe, illegal} = tally_votes(votes)

    # Adds the response to the questions map and return the whole round, with old history and all.
    # Catchall to have ties bumped as maybe.
    cond do
    yes >= threshold -> {:yes, add_response(round, :yes)}
    no >= threshold -> {:no, add_response(round, :no)}
    maybe >= threshold -> {:maybe, add_response(round, :maybe)}
    illegal >= threshold -> {:illegal, add_response(round, :illegal)}
    true -> {:maybe, add_response(round, :maybe)}
    end
  end

  defp tally_votes(votes) do
  values =
    votes
    |> Enum.sort()
    |> hd()
    |> elem(1)
    |> Map.values()
    |> Enum.frequencies()

    {
      Map.get(values, :yes, 0),
      Map.get(values, :no, 0),
      Map.get(values, :maybe, 0),
      Map.get(values, :illegal, 0)
    }
  end

  def add_response(round, answer) do
    current_q = round.votes_per_question |> Map.keys() |> Enum.sort(:desc) |> hd()

    new_q =
    round.questions
    |> Enum.reduce([], fn q, acc -> 
        if Map.keys(q) == [current_q], do: acc ++ [%{current_q => answer }], else: acc ++ [q]
      end)
    
    Map.put(round, :questions, new_q)
  end

  # I'll get to this when I need to.
  # def get_current_question(round) do
  #   non_empty = Enum.reject(round.questions, fn {_k, v} -> v == %{} end)
  #   if non_empty != [] do
  #     highest_key = Enum.sort(non_empty, :desc) |> hd()
  #
  #   else
  #     1
  #   end
  # end

  defp gen_question_stubs() do
    Enum.map(1..@questions_per_round, fn x -> %{x => %{}} end)
  end
end
