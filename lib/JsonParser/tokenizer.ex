defmodule JsonParser.Tokenizer do
  require Logger
  require String
  
  @moduledoc """
  This will parse wrong JSON and output a list of tuples with the tokens. 
  These should look like this: 
  [
        {0, :open_bracket, "{"},
        {1, :quote, "\""},
        {2, :string, "invalid"},
        {3, :quote, "\""},
        {4, :string, "="},
        {5, :quote, "\""},
        {6, :string, "json"},
        {7, :quote, "\""},
        {8, :close_bracket, "}"}
    ]
  """


  def main(string) do
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
    
    cond do
    current_type == :string || current_type == :whitespace && prev_type == :quote ->
      new_char = {prev_index, :string, "#{prev_val}#{current_val}"}
      acc = [new_char]
      maybe_concat(acc, new_char, new_list)

    current_type == :int && prev_type == :colon ->
      new_char = {prev_index, :int, "#{prev_val}#{current_val}"}
      acc = [new_char]
      maybe_concat(acc, new_char, new_list)

    true -> 
      new_char = {prev_index + 1, current_type, current_val}
      acc = [char, new_char]
      maybe_concat(acc, new_char, new_list)
    end 
  end

  defp maybe_concat(acc, char, list) when list != [] do
    {prev_index, prev_type, prev_val} = char
    
    {precursor_char, new_list} = List.pop_at(list, 0)
    
    {current_type, current_val} = get_type(precursor_char)
    
    cond do 
    current_type == :string && prev_type == :string ->
      new_char = {prev_index, :string, "#{prev_val}#{current_val}"}
      new_acc = List.replace_at(acc, prev_index, new_char)
      maybe_concat(new_acc, new_char, new_list)

    current_type == :int && prev_type == :int ->
      new_char = {prev_index, :int, "#{prev_val}#{current_val}"}
      new_acc = List.replace_at(acc, prev_index, new_char)
      maybe_concat(new_acc, new_char, new_list)     

    true ->
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
      "," -> {:comma, char}
      "[" -> {:open_square, char}
      "]" -> {:close_square, char}
      _ -> string_or_int(char)
    end
  end

  defp string_or_int(char) do
    try do
      _x = String.to_integer(char)
      {:int, char}
    rescue
      _e ->
      whitespace? = Regex.match?(~r/[[:cntrl:][:blank:]]/, char)
        if whitespace? == true do
          {:whitespace, char}
        else 
          {:string, char}
        end    
    end
  end
end
