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


  defp visitor([first | _tail] = list, acc, node) when acc == %{} and is_new_node?(first) do
      {list, acc} = create_node(list, node)
      acc = %{List.last(node) => acc}
      Logger.debug([
      function: "map.put_new/3",
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      ])
      visitor(list, acc, node, List.last(node))
  end

  defp visitor([first | _tail] = list, acc, node) when acc != %{} and is_new_node?(first) do
    {list, pre_acc} = create_node(list, node)
    address = List.last(node)
    acc = Map.put_new(acc, address, pre_acc)

    Logger.debug([
      function: "map.put_new/3",
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      target: address,
    ])
    
    visitor(list, acc, node, address)
  end

  defp visitor([first | _tail] = list, acc, node, address) when list != [] and not is_new_node?(first) do

    {new_list, new, acc} = 
      get_key(list)
      |> get_value()
      |> maybe_insert_node(acc, address)
      |> get_separator()

    new_acc = put_in(acc[address][:pairs], List.flatten([acc[address][:pairs], new]))

    Logger.debug([
      function: "put_in/3",
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      target: address,
    ])

    visitor(new_list, new_acc, node, address)
  end  

  defp visitor(list, acc, node, address) when list != [] and is_map_key(acc, address) do
    {new_list, new, acc} = 
      get_key(list)
      |> get_value()
      |> maybe_insert_node(acc, address)
      |> get_separator()

    new_acc = update_in(acc[address][:pairs], &(check_merge(&1, new)))
    
    Logger.debug([
      function: "update_in/3",
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      target: address,
    ])
    
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
  defguardp is_start_of_string(first, second) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :string
  
  defp get_key([first, second, third | tail] = _list) when is_string(first, second, third) do
    string = get_val(second)
    {tail, "\"#{string}\""}
  end

  defp get_key([first, second | _tail] = list) when is_start_of_string(first, second) do
    get_end_of_proper_string(list)
  end



# Rules for evaluating values.
  defguard is_comma(token) when elem(elem(token, 1), 0) == :comma
  defguard is_comma_or_bracket(token) when elem(elem(token, 1), 0) == :comma or elem(elem(token, 1), 0) == :close_bracket
  defguardp is_colon(token) when elem(elem(token, 1), 0) == :colon 
  defguardp is_int(first) when elem(elem(first, 1), 0) == :int
  defguardp is_node_slot(first, second) when is_colon(first) and elem(first, 0) + 2 < elem(second, 0) and is_comma_or_bracket(second) 
  defguardp is_empty_string(first, second) when elem(elem(first, 1), 0) == :quote and elem(elem(second, 1), 0) == :quote
  defguardp is_bool(first) when elem(elem(first, 1), 1) == "true" or elem(elem(first, 1), 1) == "false" 
  defguardp is_value_list(first, second) when elem(elem(first, 1), 0) == :colon and elem(elem(second, 1), 0) == :open_square

  

  # unwrap the tuple
  defp get_value({list, key} = _tuple) do
    get_value(list, key)
  end
  

  # basic logic check (is this a correctly formatted value?)
  defp get_value([first, second | _tail] = list, key) when is_node_slot(first, second) do
    {:insert_node, list, key}
  end

  defp get_value([first, second | new_list] = _list, key) when is_value_list(first, second) do
    {:insert_list, new_list, key}
  end

  defp get_value([first | new_list] = _list, key) when is_colon(first) do
    evaluate_value_type(new_list, key)
  end

  

  # basic format detection rules 
  defp evaluate_value_type([first | tail] = _list, key) when is_int(first) do
    int = get_val(first)
    {tail, %{key => int}}
  end
 
  defp evaluate_value_type([first, second, third | tail] = _list, key) when is_string(first, second, third) do
    string = get_val(second)
    {tail, %{key => "#{string}"}}
  end

  defp evaluate_value_type([first, second, third | tail ] = _list, key) when is_empty_string(first, second) and is_comma(third) do
    {List.flatten([[third], [tail]]), %{key => ""}}
  end
  
  defp evaluate_value_type(list, key) when list == [] do 
    {:insert_node, list, key}
  end

  defp evaluate_value_type([first, second | _tail ] = list, key) when is_start_of_string(first, second) do
    {new_tail, val} = get_end_of_proper_string(list)
    {new_tail, %{key => val}}
  end

  defp evaluate_value_type([first | tail ] = _list, key) when is_bool(first) do
    {tail, %{key => get_val(first)}}
  end
  


  # if the value is a node
  defp maybe_insert_node({command, [first, second | tail ] = list, key} = _tuple, acc, address) when command == :insert_node and list != [] do
    start = elem(first, 0)
    finish = elem(second, 0)
    address_to_add = Map.keys(acc[address]) |> Enum.reject(&(&1 == address)) |> List.first()

    case correct?(start, finish, acc, address_to_add) do
      :ok ->
        key_val = %{key => acc[address_to_add].pairs}

        new_acc = Map.reject(acc, fn {k, _v} -> k == address_to_add end)

        {List.flatten([[second], [tail]]), key_val, new_acc}
      :error ->
        {list, key, acc}
    end 
  end

  defp maybe_insert_node({command, [first, second | tail] = _list, key} = _tuple, prev_acc, address) when command == :insert_list do
    final_index = get_final_square(tail)

    filtered = Enum.reject(tail, fn t -> elem(t, 0) > final_index || elem(elem(t, 1), 0) != :comma end)



    {tail, filtered, %{}}
  end

  # So, this guy here is a thing. Because I am consuming the list to be able to tell when I'm done with it, 
  # there's also no metadata to go off of when I get to the last node because it has been consumed + there 
  # is no next node. So, in order to cope with a nested object on the last key of an object, I will simply 
  # need to trust that my logic above is correct. Can't double check it with correct?() since there's nothing
  # to go off of. So trust me on this one. It needs to be correct. :)
  defp maybe_insert_node({command, list, key} = _tuple, prev_acc, address) when command == :insert_node and list == [] do
    full_address = get_in(prev_acc[address], [:address]) 

    child = Enum.reduce(prev_acc, [], fn {k, _v}, acc -> 
          {child, parent} = List.pop_at(get_in(prev_acc[k], [:address]), -1)
            if parent == full_address do
              acc = check_merge(acc, child)
              acc
            else 
              acc
            end
          end)

    if is_list(child) do
      last = 
        Enum.sort(child)
        |> List.first() 

        key_val = %{key => prev_acc[last].pairs}

        new_acc = Map.reject(prev_acc, fn {k, _v} -> k == last end)

        Logger.debug([
          message: "inserted node",
          target: full_address,
          inserted: last,
        ])

        {[], key_val, new_acc}
     else
      key_val = %{key => prev_acc[child].pairs}

      new_acc = Map.reject(prev_acc, fn {k, _v} -> k == child end)

        Logger.debug([
          message: "inserted node",
          target: full_address,
          inserted: child,
        ])

      {[], key_val, new_acc}
    end
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
  defp get_end_of_proper_string([first, second | tail] = list) when elem(elem(first, 1), 0) == :quote do
    {end_index, _} = List.keyfind(tail, {:quote, "\""}, 1)
    {start_index, _} = second
    string = 
      Enum.filter(list, fn {i, _val} -> i >= start_index && i <= end_index end)
      |> Enum.reduce([], fn v, acc -> acc ++ [get_val(v)] end)
      |> Enum.join()

    new_tail = Enum.reject(list, fn {i, _v} -> i < end_index + 1 end)
    {new_tail, string}
  end

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

  defp check_merge(old, new) when old == [] or old == nil do
    new
  end

  defp check_merge(old, new) do
    List.flatten([[old], [new]])
  end
 
 defp get_final_square(tail) do
    final = 
      Enum.filter(tail, fn t -> 
        elem(elem(t, 1), 0) == :close_square 
      end)

      
    if length(final) > 1 do 
      List.keysort(final, 0)
      |> List.first()
      |> elem(1)
    
    else 
      [tuple] = final
      IO.inspect(tuple)
      elem(tuple, 1)
    end
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
