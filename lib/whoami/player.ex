defmodule Whoami.Player do

  @moduledoc """
  Defines a player and its basic characteristics
  """
  @enforce_keys [:name, :id]

  defstruct [
    name: nil, 
    id: nil, 
    points: 0,
    wins: 0, 
    ready: false
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          points: non_neg_integer(),
          wins: non_neg_integer(),
          ready: boolean()
        }

  def create_player(user) when is_binary(user)do
    %__MODULE__{
      name: user,
      id: Whoami.generate_id(),
    }
  end
end
