defmodule Whoami.Lobby do
  @moduledoc """
  Defines the struct for a lobby
  """

  defstruct [:id, :player_count, :captain, :players]
end
