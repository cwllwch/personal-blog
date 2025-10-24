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
  nodes =
  Enum.reverse(nodes)
  |> Enum.reduce(%{}, fn node, acc ->
      IO.inspect(acc)
      get_in(tree, List.flatten([node, :content]))
      |> visitor(acc, node)
    end)

  Logger.info(
  %{
      message: "successfully ",
      start: nodes[0].start, 
      end: nodes[0].end, 
      type: nodes[0].type
    }
  )

  nodes[0].pairs
  end

  # Orchestrates the node verification rules. Start by initiating an accumulator which
  # will be passed around every rule
  defguardp is_new_node?(first) when elem(elem(first, 1), 0) == :open_bracket 

  defp visitor([first | tail] = list, acc, node) when acc == %{} and is_new_node?(first) do
    try do
      {list, acc} = create_node(list, node)
      acc = %{List.last(node) => acc}
      visitor(list, acc, node, List.last(node))
    rescue 
      e ->
        [s, t, f, g, h, i, j | _rest] = tail
        context = List.to_string(List.flatten([get_val(first), get_val(s), get_val(t), get_val(f), get_val(g), get_val(h), get_val(i), get_val(j)]))
        formatted = Exception.format_error(e, __STACKTRACE__)
        Logger.error(%{
          message: "Unexpected error",
          error: formatted.general,
          node: node,
          context: context,
          acc_paths: acc
        })
    end
  end

  defp visitor([first | _tail] = list, acc, node) when acc != %{} and is_new_node?(first) do
    {list, pre_acc} = create_node(list, node)
    address = List.last(node)
    acc = Map.put_new(%{}, address, pre_acc)
    visitor(list, acc, node, address)
  end

  defp visitor([first | _tail] = list, acc, node, address) when list != [] and not is_new_node?(first) do
    {new_list, new, acc} = 
      get_key(list)
      |> get_value()
      |> maybe_insert_node(acc, address)
      |> get_separator()

    new_acc = put_in(acc[address][:pairs], new)

    visitor(new_list, new_acc, node, address)
  end  

  defp visitor(list, acc, node, address) when list != [] and is_map_key(acc, address) do
    {new_list, new, acc} = 
      get_key(list)
      |> get_value()
      |> maybe_insert_node(acc, address)
      |> get_separator()

    new_acc = update_in(acc[address].pairs, &(check_merge(&1, new)))
    visitor(new_list, new_acc, node, address)
  end

  defp visitor(_list, acc, _node, _address) do
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
      %{type: "Object", start: index, end: nil, pairs: [], address: node}
    }
  end

  defp starts_with_bracket?(index, _type, _char, node) do
    {:error, 
      %{type: "Improper object", start: index, end: nil, pairs: [], address: node }
    }
  end

  defp ends_with_bracket?(index, type, char, acc, node) when type == :close_bracket and char == "}" do
    %{acc | address: node, end: index}
  end
  
  defp ends_with_bracket?(index, _type, _char, acc, _node) do
    %{acc | acc.type => "Improper object", end: index}
  end



# Rules for evaluating the keys. 
  defguard is_string(first, second, third) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :string and elem(elem(third, 1), 0) == :quote
 
  defp get_key([first, second, third | tail] = _list) when is_string(first, second, third) do
    string = get_val(second)
    {tail, "\"#{string}\""}
  end



# Rules for evaluating values.
  defguard is_comma(token) when elem(elem(token, 1), 0) == :comma
  defguardp is_colon(token) when elem(elem(token, 1), 0) == :colon 
  defguardp is_int(first) when elem(elem(first, 1), 0) == :int
  defguardp is_start_of_string(first, second) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :string
  defguardp is_node_slot(first, second) when is_colon(first) and elem(first, 0) + 2 < elem(second, 0) and is_comma(second)

  defp get_value({list, key} = _tuple) do
    get_value(list, key)
  end
  
  defp get_value([first, second | _tail] = list, key) when is_node_slot(first, second) do
    {:insert_node, list, key}
  end

  defp get_value([first | new_list] = _list, key) when is_colon(first) do
    evaluate_value_type(new_list, key)  
  end
  
  defp evaluate_value_type([first | tail] = _list, key) when is_int(first) do
    int = get_val(first)
    {tail, %{key => int}}
  end
 
  defp evaluate_value_type([first, second, third | tail] = _list, key) when is_string(first, second, third) do
    string = get_val(second)
    {tail, %{key => "#{string}"}}
  end
  
  defp evaluate_value_type(list, key) when list == [] do 
    {:insert_node, list, key}
  end

  defp evaluate_value_type([first, second | tail] = list, key) when is_start_of_string(first, second) do
    {end_index, _} = List.keyfind(tail, {:quote, "\""}, 1)
    {start_index, _} = first
    val = 
      Enum.filter(list, fn {i, _val} -> i >= start_index && i <= end_index end)
      |> Enum.reduce([], fn v, acc -> acc ++ [get_val(v)] end)
      |> Enum.join()

    new_tail = Enum.reject(list, fn {i, _v} -> i < end_index + 1 end)
    {new_tail, %{key => val}}
  end
  
  defp maybe_insert_node({command, [first, second | tail ] = list, key} = _tuple, acc, address) when command == :insert_node do
    start = elem(first, 0)
    finish = elem(second, 0)
    address_to_add = Map.keys(acc) |> Enum.reject(&(&1 == address)) |> List.first()

    case correct?(start, finish, acc, address_to_add) do
      :ok ->
        key_val = %{key => acc[address_to_add].pairs}

        new_acc = Map.reject(acc, fn {k, _v} -> k == address_to_add end)

        {List.flatten([[second], [tail]]), key_val, new_acc}
      :error ->
        {list, key, acc}
    end 
  end

  # So, this guy here is a thing. Because I am consuming the list to be able to tell when I'm done with it, 
  # there's also no metadata to go off of when I get to the last node because it has been consumed + there 
  # is no next node. So, in order to cope with a nested object on the last key of an object, I will simply 
  # need to trust that my logic above is correct. Can't double check it with correct?() since there's nothing
  # to go off of. So trust me on this one. It needs to be correct. :)
  defp maybe_insert_node({command, list, key} = _tuple, acc, address) when command == :insert_node and list == [] do
    address_to_add = Map.keys(acc) |> Enum.reject(&(&1 == address)) |> List.first()
    key_val = %{key => acc[address_to_add].pairs}
    new_acc = Map.reject(acc, fn {k, _v} -> k == address_to_add end)
    {[], key_val, new_acc}
  end

  defp maybe_insert_node({list, key} = _tuple, acc, _address) do
    {list, key, acc}
  end

# Rules for evaluating separation of key-value pairs or other elements
  defp get_separator({list, key_val, acc} = _tuple) do
    get_separator(list, key_val, acc)
  end

  defp get_separator([first | tail] = _list, key_val, acc) when is_comma(first) do
    {tail, key_val, acc}
  end

  defp get_separator(list, key_val, acc) when list == [] do
    {[], key_val, acc}
  end




# Helper functions
  defp get_val(tuple) do
    elem(elem(tuple, 1), 1)
  end

  defp correct?(start, finish, acc, address) do
    node_start = acc[address].start 
    node_end = acc[address].end 

    if start + 1 == node_start && finish - 1 == node_end do
      :ok
      else
      Logger.error(
      %{message: "Got a wrong call node insertion request", 
        acc: acc,
        address: address,
        requested_start_index: node_start,
        requested_start_end: node_end,
        actual_start: start,
        actual_end: finish
        }
      )  
       :error
    end
  end

  defp check_merge(old, new) when old == [] do
    new
  end

  defp check_merge(old, new) do
    List.flatten([[old], [new]])
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


