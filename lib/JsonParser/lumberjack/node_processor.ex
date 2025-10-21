defmodule JsonParser.Lumberjack.NodeProcessor do
  @moduledoc """
  The final step in the AST processing pipeline.
  This module will take the tree and addresses and process each node 
  in order to make them into a proper AST. 
  """

  require Logger

  def main(tree, nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      get_in(tree, List.flatten([node, :content]))
      |> visitor(acc, node)
    end)
  end

  # Orchestrates the node verification rules. Start by initiating an accumulator which
  # will be passed around every rule
  defp visitor(list, acc, node) when acc == %{} do
    {list, acc} = evaluate_brackets(list)
    visitor(list, acc, node)
  end

  defp visitor(list, acc, node) when list != [] do
    get_value(list)
    |> IO.inspect()
  end

  defp visitor(list, acc, _node) when list == [] do 
    {list, acc}
  end

# Evaluates the node itself, where it starts and ends. 
# Also starts up the tree. 
  defp evaluate_brackets(list) do
    {{f_index, {f_type, f_char}}, list} = List.pop_at(list, 0)
    check = starts_with_bracket?(f_index, f_type, f_char)
    case check do
      {:ok, acc} -> 
        {{e_index, {e_type, e_char}}, new_list} = List.pop_at(list, -1)
        acc = ends_with_bracket?(e_index, e_type, e_char, acc)
        {new_list, acc}
      {:error, _} -> format_error(check, list)
    end
  end

  defp starts_with_bracket?(index, type, char) when type == :open_bracket and char == "{" do
    {:ok, 
      %{type: "Object", name: "main", start: index, end: nil, pairs: [] }
    }
  end

  defp starts_with_bracket?(index, _type, _char) do
    {:error, 
      %{type: "Improper object", name: "json", start: index, end: nil, pairs: [] }
    }
  end

  defp ends_with_bracket?(index, type, char, acc) when type == :close_bracket and char == "}" do
    %{acc | end: index}
  end
  
  defp ends_with_bracket?(index, _type, _char, acc) do
    %{acc | acc.type => "Improper object", end: index}
  end

# Rules for evaluating the keys. 

  defguard is_string(first, second, third) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :string and elem(elem(third, 1), 0) == :quote
 
  defp get_value([first, second, third | tail] = _list) when is_string(first, second, third) do
    string = get_type(second)
    {tail, "#{string}"}
  end

# Helper functions 

  defp get_type(tuple) do
    elem(elem(tuple, 1), 1)
  end

# Error formatting

  defp format_error({check, {index, _type, char}} = _tuple, list) when check == :error and index < 5 do
    preview = make_preview(list, index)
    {:error, preview, char}
  end

  defp format_error({_check, {index, type, char}} = _tuple, list) do
    preview = make_preview(list, index)
    
    Logger.error(%{
      message: "non-error passed to error handler",
      params: [
        preview: preview,
        index: index,
        type: type,
        char: char
      ]
    })
    {:error, preview, char}
  end

  defp make_preview(list, index) do
    Enum.filter(list, fn {indexes, {_types, _chars}} -> 
      indexes < index - 3 && indexes > index + 3
      end)
    |> Enum.map_join(fn {_indexes, {_type, char}} -> char end) 
  end
end
