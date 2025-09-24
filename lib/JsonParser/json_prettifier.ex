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
    indexer(not_json)
    |> Enum.reduce([], fn tuple, acc ->
      string = "Index: #{elem(tuple, 0)} | Type: #{elem(tuple, 1)} | Value: #{elem(tuple, 2)} \n"
      List.insert_at(acc, -1, string)
      end) 
    |> List.to_string()
  end

  def indexer(string) do
  last = String.length(string) - 1 

    String.graphemes(string)
    |> add_types(last)
  end

  defp add_types(list, last) do
    {char, new_list} = List.pop_at(list, 0)
    new_char = get_type(char)
    |> Tuple.insert_at(0, 0)
    
    if last < 9 do
      ["This is too short to be a json"]
    else
      maybe_concat(new_char, new_list)
    end
  end

  defp maybe_concat(char, list) do
    {prev_index, prev_type, prev_val} = char
    
    {precursor_char, new_list} = List.pop_at(list, 0)
    
    {current_type, current_val} = get_type(precursor_char)
    
    if current_type == :string && prev_type == :string do
      new_char = {prev_index, :string, prev_val <> current_val}
      acc = [new_char]
      maybe_concat(acc, new_char, new_list)
    else 
      new_char = {prev_index + 1, current_type, current_val}
      acc = [char, new_char]
      maybe_concat(acc, new_char, new_list)
    end 
  end

  defp maybe_concat(acc, char, list) when list != [] do
    {prev_index, prev_type, prev_val} = char
    
    {precursor_char, new_list} = List.pop_at(list, 0)
    
    {current_type, current_val} = get_type(precursor_char)
    
    if current_type == :string && prev_type == :string do
      new_char = {prev_index, :string, prev_val <> current_val}
      new_acc = List.replace_at(acc, prev_index, new_char)
      maybe_concat(new_acc, new_char, new_list)
    else 
      new_char = {prev_index + 1, current_type, current_val}
      new_acc = List.insert_at(acc, prev_index + 1, new_char)
      maybe_concat(new_acc, new_char, new_list)
    end 
  end

  defp maybe_concat(acc, _char, list) when list == [] do
    acc
  end

  defp get_type(char) do
    case char do
      "{" -> {:open_bracket, char}
      "}" -> {:close_bracket, char}
      "\"" -> {:quote, char}
      ":" -> {:colon, char}
      char when is_binary(char) -> {:string, char}
  end
end
end

