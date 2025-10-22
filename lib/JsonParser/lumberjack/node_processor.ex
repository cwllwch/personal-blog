defmodule JsonParser.Lumberjack.NodeProcessor do
  @moduledoc """
  The final step in the AST processing pipeline.
  This module will take the tree and addresses and process each node 
  in order to make them into a proper AST. 
  """

  require Logger
  require Exception

  @doc """
  Gets the structure of the tree and the address of the nodes, then builds essentially 
  a new tree.
  """
  def main(tree, nodes) do
  nodes = Enum.reverse(nodes)
    Enum.reduce(nodes, %{}, fn node, acc ->
      get_in(tree, List.flatten([node, :content]))
      |> visitor(acc, node)
      |> IO.inspect()
    end)
  end

  # Orchestrates the node verification rules. Start by initiating an accumulator which
  # will be passed around every rule
  defp visitor(list, acc, node) when acc == %{} do
    {list, acc} = create_node(list, node)
    visitor(list, acc, node)
  end

  defp visitor(list, acc, node) when list != [] do
    {new_list, new} = 
      get_key(list)
      |> get_value()
      |> get_separator()


    new_acc = %{acc | pairs: "#{acc.pairs}, #{new}"}

    visitor(new_list, new_acc, node)
  end

  defp visitor(list, acc, _node) when list == [] do
    acc
  end



# Evaluates the node itself, where it starts and ends. 
  defp create_node(list, node) do
    {{f_index, {f_type, f_char}}, list} = List.pop_at(list, 0)
    check = starts_with_bracket?(f_index, f_type, f_char, node)
    case check do
      {:ok, acc} -> 
        {{e_index, {e_type, e_char}}, new_list} = List.pop_at(list, -1)
        acc = ends_with_bracket?(e_index, e_type, e_char, acc, node)
        {new_list, acc}
      {:error, _} -> format_error(check, list)
    end
  end

  defp starts_with_bracket?(index, type, char, node) when type == :open_bracket and char == "{" do
    {:ok, 
      %{type: "Object", name: "main", start: index, end: nil, pairs: [], address: node}
    }
  end

  defp starts_with_bracket?(index, _type, _char, node) do
    {:error, 
      %{type: "Improper object", name: "json", start: index, end: nil, pairs: [], address: node }
    }
  end

  defp ends_with_bracket?(index, type, char, acc, node) when type == :close_bracket and char == "}" do
    %{acc | address: node, end: index}
  end
  
  defp ends_with_bracket?(index, _type, _char, acc, node) do
    %{acc | acc.type => "Improper object", address: node, end: index}
  end



# Rules for evaluating the keys. 
  defguard is_string(first, second, third) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :string and elem(elem(third, 1), 0) == :quote
 
  defp get_key([first, second, third | tail] = _list) when is_string(first, second, third) do
    string = get_val(second)
    {tail, "\"#{string}\""}
  end



# Rules for evaluating values.
  defguard is_colon(token) when elem(elem(token, 1), 0) == :colon  
  defguard is_int(first) when elem(elem(first, 1), 0) == :int
  defguard is_start_of_string(first, second) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :string

  defp get_value({list, key} = _tuple) do
    get_value(list, key)
  end

  defp get_value([first | new_list] = _list, key) when is_colon(first) do
    evaluate_value_type(new_list, key)  
  end

  defp evaluate_value_type([first | tail] = _list, key) when is_int(first) do
    int = get_val(first)
    {tail, "#{key}:#{int}"}
  end
 
  defp evaluate_value_type([first, second, third | tail] = _list, key) when is_string(first, second, third) do
    string = get_val(second)
    {tail, "#{key}:\"#{string}\""}
  end
  
  defp evaluate_value_type(list, key) when list == [] do 
    {list, key}
  end

  defp evaluate_value_type([first, second | tail] = list, key) when is_start_of_string(first, second) do
    {end_index, _} = List.keyfind(tail, {:quote, "\""}, 1)
    {start_index, _} = first
    val = 
      Enum.filter(list, fn {i, _val} -> i >= start_index && i <= end_index end)
      |> Enum.reduce([], fn v, acc -> acc ++ [get_val(v)] end)
      |> Enum.join()

    new_tail = Enum.reject(list, fn {i, _v} -> i < end_index + 1 end)
    {new_tail, "#{key}:#{val}"}
  end



# Rules for evaluating separation of key-value pairs or other elements
  defguard is_comma(token) when elem(elem(token, 1), 0) == :comma

  defp get_separator({list, key_val} = _tuple) do
    get_separator(list, key_val)
  end

  defp get_separator([first | tail] = _list, key_val) when is_comma(first) do
    {tail, "#{key_val}"}
  end

  defp get_separator(list, key_val) when list == [] do
    {[], "#{key_val}"}
  end


# Helper functions
  defp get_val(tuple) do
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
