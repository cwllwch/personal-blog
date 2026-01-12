defmodule Whoami.LobbyStruct do
  @moduledoc """
  Defines the struct for a lobby
  """

  defstruct [
    :id, 
    :player_count, 
    :captain, 
    :players, 
    :last_interaction, 
    :stage, 
    :ban_list, 
    :disc_list, 
    :word_in_play,
    :word_map, 
    :word_queue
  ]
end
