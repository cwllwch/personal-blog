defmodule Whoami.LobbyStruct do
  @moduledoc """
  Defines the struct for a lobby
  """

  defstruct [:id, :player_count, :captain, :players, :last_interaction, :stage, :ban_list]
end
