defmodule Whoami.Lobby do
  
  @moduledoc """
  Defines the struct for a lobby
  """

  @enforce_keys [:id, :player_count]
  
  defstruct [:id, :player_count]

end
