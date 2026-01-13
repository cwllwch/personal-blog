defmodule Whoami.Player do
  alias Whoami.Player

  @moduledoc """
  Defines a player and its basic characteristics
  """
  @enforce_keys [:name, :id]

  defstruct [:name, :id, :points, :wins, :ready]

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          points: non_neg_integer(),
          wins: non_neg_integer(),
          ready: boolean()
        }

  def create_player(user) do
    %Player{
      name: user,
      id: Whoami.generate_id(),
      points: 0,
      ready: false,
      wins: 0
    }
  end
end
