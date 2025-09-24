defmodule JsonParser.JsonPrettifier do
  alias Jason
  require String
  require Logger
  @moduledoc """
  This module takes a JSON, checks if it is badly formatted, parses it if it is
  and then returns a prettified version of it.
  """


  def prettify(json) do
    case Jason.decode(json) do
      {:ok, parsed} ->
        Jason.encode!(parsed, pretty: true)
      {:error, _reason} ->
        new_json = parse_this_into_json(json)
        new_json
    end
  end

  def parse_this_into_json(not_json) do
    index_map = indexer(not_json)
    |> List.to_string()
  end

  def indexer(string) do
  last = String.length(string) - 1 

    String.graphemes(string)
    |> add_types(last)
    |> IO.inspect()
  end

  defp add_types(list, last) do
    char = List.first(list)
    |> get_type()
    |> Tuple.insert_at(0, 0)
    
    if last <= 1 do
      char
    else
      maybe_concat(char, list, last)
    end
  end

  defp maybe_concat() do
    
  end

  defp get_type(char) do
    case char do
      "{" -> {:open_bracket, char}
      "\"" -> {:quote, char}
      char when is_binary(char) -> {:string, char}
  end
end
end

