defmodule JsonParser.JsonPrettifier do

  @moduledoc """
  This module takes a JSON, checks if it is badly formatted, parses it if it is 
  and then returns a prettified version of it.
  """


  def prettify(json) do
    case Jason.decode(json) do
      {:ok, parsed} ->
        Jason.encode!(parsed, pretty: true)
      {:error, _reason} -> 
        new_json = parse_this_json(json)
        new_json
    end
  end

  defp parse_this_json(_json) do
    "Still to be implemented."
  end
end
