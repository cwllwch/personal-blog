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

  defp tokenizer(acc, full_map, index, length) when (index < length) do
    char = List.keyfind(full_map, index, 1)
    |> elem(0)
    |> typer()

    case char do
      {:string, _} -> 
        {new_char, new_index} = maybe_concat(full_map, char, index, length) 
        Map.put(acc, new_index, new_char)
        |> tokenizer(full_map, new_index, length)
      {:integer, _} ->
        {new_char, new_index} = maybe_concat(full_map, char, index, length) 
        Map.put(acc, new_index, new_char)
        |> tokenizer(full_map, new_index, length)
      {_, _} -> 
        new_index = index + 1 
        Map.put(acc, new_index, char)
        |> tokenizer(full_map, new_index, length)
    end 
  end

  defp tokenizer(acc, _full_map, index, length) when (index >= length) do
    acc
  end

  defp maybe_concat(list, char, index, length) when (index < length) do
    pointer = index + 1
    nxt_char = List.keyfind(list, pointer, 1)
    |> elem(0)
    |> typer()

    {prev_type, prev_val} = char
    {nxt_type, nxt_val} = nxt_char
    
    case prev_type && nxt_type do
      :string -> 
        new_char = {nxt_type, prev_val <> nxt_val}
        maybe_concat(new_char, list, index, pointer, length)
      :integer ->  
        new_char = {nxt_type, prev_val <> nxt_val}
        maybe_concat(new_char, list, index, pointer, length)
      _ ->
        new_index = index + 1
        {new_index, char}
        
    end
  end

  defp maybe_concat(char, list, index, pointer, length) when (pointer < length) do
    {og_type, og_val} = char

    nxt_char = List.keyfind(list, pointer, 1)
    |> elem(0)
    |> typer()
    
    Logger.info("Next char: #{inspect(nxt_char)}")
    
    {nxt_type, nxt_val} = nxt_char
    new_pointer = pointer + 1

    Logger.info(nxt_val <> "   " <> og_val)
        
    case og_type && nxt_type do
      :string -> 
        new_char = {og_type, og_val <> nxt_val}
        maybe_concat(new_char, list, index, new_pointer, length)
      :integer -> 
        new_char = {og_type, nxt_val <> nxt_val}
        maybe_concat(new_char, list, index, new_pointer, length)
      _ ->
        {index, char}
    end 
  end

  defp maybe_concat(char, _list, index, pointer, length) when (pointer == length) do
    {index, char}
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

