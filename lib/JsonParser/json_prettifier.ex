defmodule JsonParser.JsonPrettifier do
  alias Jason
  require Atom
  require Logger
  require Integer
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

  defp parse_this_json(json) do
    parsed_list = String.graphemes(json)
    |> Enum.with_index()
    |> tokenizer()    

    Logger.info(parsed_list)

    Enum.reduce(parsed_list, "", fn tuple, acc ->
      {index, {type, char}} = tuple
      stringed_atom = Atom.to_string(type)
      stringed_integer = Integer.to_string(index)
      acc <> "index: " <> stringed_integer <> " | type: " <> stringed_atom <> " | value: " <> char <> "\n"
    end)
    

  end

  defp tokenizer(indexed_map) do
    char = List.keyfind(indexed_map, 0, 1)
    char_with_type = elem(char, 0) 
    |> typer()

    {_, length} = List.last(indexed_map)

    acc = %{0 => char_with_type}
    |> tokenizer(indexed_map, 1, length)

    acc
  end

  defp tokenizer(acc, full_map, index, length) when (index <= length) do
    char = List.keyfind(full_map, index, 1)
    char_with_type = elem(char, 0)
    |> typer()

    new_acc = Map.put(acc, index, char_with_type)
    new_index = index + 1

    tokenizer(new_acc, full_map, new_index, length)
  end

  defp tokenizer(acc, _full_map, index, length) when (index > length) do
    acc
  end

  defp typer(char) do
    case char do
      "{" -> 
        {:open_bracket, char}
      "}" ->
        {:close_bracket, char}
      ":" ->
        {:colon, char}
      "\\" -> 
        {:escape, char}
      "\"" ->
        {:quote, char}
      char when is_integer(char) ->
        {:integer, char}
      char when is_binary(char) ->
        {:string, char}
      _ ->
        {:other, char}
    end
  end
end

