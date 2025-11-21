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

  @list_to_concat [:string, :empty_string, :colon, :int, :open_bracket, :close_bracket]

  def main(string) do
    last = String.length(string) - 1

    result =
      String.graphemes(string)
      |> add_types(last)

    {:ok, result}
  end

  defp add_types(list, last) do
    {char, new_list} = List.pop_at(list, 0)

    new_char =
      get_type(char)
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
      current_type in @list_to_concat && prev_type == :string ->
        new_char =
          {prev_index, :string, "#{prev_val}#{current_val}"}
          |> bool_override()

        acc = [new_char]
        maybe_concat(acc, new_char, new_list)

      current_type == :int && prev_type == :colon ->
        new_char = {prev_index, :int, "#{prev_val}#{current_val}"}
        acc = [new_char]
        maybe_concat(acc, new_char, new_list)

      true ->
        new_char =
          {prev_index + 1, current_type, current_val}
          |> bool_override()

        acc = [char, new_char]
        maybe_concat(acc, new_char, new_list)
    end
  end

  defp maybe_concat(acc, char, list) when list != [] do
    {prev_index, prev_type, prev_val} = char

    {precursor_char, new_list} = List.pop_at(list, 0)

    {current_type, current_val} = get_type(precursor_char)

    cond do
      current_type in @list_to_concat && prev_type == :string ->
        new_char =
          {prev_index, :string, "#{prev_val}#{current_val}"}
          |> bool_override()

        new_acc = List.replace_at(acc, prev_index, new_char)
        maybe_concat(new_acc, new_char, new_list)

      current_type == :int && prev_type == :int ->
        new_char = {prev_index, :int, "#{prev_val}#{current_val}"}
        new_acc = List.replace_at(acc, prev_index, new_char)
        maybe_concat(new_acc, new_char, new_list)

      true ->
        new_char =
          {prev_index + 1, current_type, current_val}
          |> bool_override()

        new_acc = List.insert_at(acc, prev_index + 1, new_char)
        maybe_concat(new_acc, new_char, new_list)
    end
  end

  defp maybe_concat(acc, _char, list) when list == [] do
    acc
  end

  defp get_type(char) when char == "{" do
    {:open_bracket, char}
  end

  defp get_type(char) when char == "}" do
    {:close_bracket, char}
  end

  defp get_type(char) when char == "\"" do
    {:quote, "\""}
  end

  defp get_type(char) when char == ":" do
    {:colon, char}
  end

  defp get_type(char) when char == "," do
    {:comma, char}
  end

  defp get_type(char) when char == "[" do
    {:open_square, char}
  end

  defp get_type(char) when char == "]" do
    {:close_square, char}
  end

  defp get_type(char) when char == "\\n" do
    {:newline, char}
  end

  defp get_type(char) when char == "\\" do
    {:escape, char}
  end

  defp get_type(char) when char == " " do
    {:empty_string, char}
  end

  defp get_type(char) do
    string_or_int(char)
  end

  defp string_or_int(char) do
    _x = String.to_integer(char)
    {:int, char}
  rescue
    _e ->
      whitespace? = Regex.match?(~r/[[:cntrl:][:blank:]]/, char)

      if whitespace? == true do
        {:empty_string, char}
      else
        {:string, char}
      end
  end

  defp bool_override({i, _t, c} = _tuple) when c == "false" do
    {i, false, c}
  end

  defp bool_override({i, _t, c} = _tuple) when c == "true" do
    {i, true, c}
  end

  defp bool_override({i, _t, c} = _tuple) when c == "null" do
    {i, :null, c}
  end

  defp bool_override(tuple) do
    tuple
  end
end
