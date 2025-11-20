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
    try do
      nodes =
        Enum.reverse(nodes)
        |> Enum.reduce(%{}, fn node, acc ->
          get_in(tree, List.flatten([node, :content]))
          |> visitor(acc, node)
        end)

      Logger.info(%{
        source: "[" <> Path.basename(__ENV__.file) <> "]",
        message: "successfully parsed json string",
        start: nodes[0].start,
        end: nodes[0].end,
        type: nodes[0].type
      })

      result = nodes[0].pairs 

      {:ok, result}
    rescue e ->
      [first, second | _] = __STACKTRACE__
      {mo_f, f_f, a_f,  me_f} = first
      {mo_s, f_s, a_s, me_s} = second

      Logger.warning([
        message: "unhandled exception",
        location: inspect(me_f[:file]) <> " at " <> inspect(me_f[:line]),
        mfa: "#{mo_f} - #{f_f}/#{length(List.flatten([a_f]))}, arguments given: #{inspect(a_f)}",
        context: "#{mo_s} - #{f_s}/#{a_s} at #{me_s[:line]}, arguments given: #{inspect(a_s)}"
      ])
      {:error, "Error inserting data into the nodes: " <> Exception.message(e)}
    end
  end

  # Orchestrates the node verification rules. Start by initiating an accumulator which
  # will be passed around every rule
  defguardp is_new_node?(first) when elem(elem(first, 1), 0) == :open_bracket

  defp visitor([first | _tail] = list, acc, node) when acc == %{} and is_new_node?(first) do
    {list, acc} = create_node(list, node)
    acc = %{List.last(node) => acc}

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "visitor-entrypoint"
    )

    visitor(list, acc, node, List.last(node))
  end

  defp visitor([first | _tail] = list, acc, node) when acc != %{} and is_new_node?(first) do
    {list, pre_acc} = create_node(list, node)
    address = List.last(node)
    acc = Map.put_new(acc, address, pre_acc)

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "map.put_new/3",
      target: address,
      node: node
    )

    visitor(list, acc, node, address)
  end

  defp visitor([first | _tail] = list, acc, node, address)
       when list != [] and not is_new_node?(first) do
    {new_list, new, acc} =
      get_key(list)
      |> get_value()
      |> maybe_insert_node(acc, address)
      |> get_separator()

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "put_in/3",
      target: address
    )

    if new != nil do
      new_acc = update_in(acc[address][:pairs], &check_merge(&1, new))
      visitor(new_list, new_acc, node, address)
    else
      visitor(new_list, acc, node, address)
    end
  end

  defp visitor(list, acc, node, address) when list != [] and is_map_key(acc, address) do
    {new_list, new, acc} =
      get_key(list)
      |> get_value()
      |> maybe_insert_node(acc, address)
      |> get_separator()

    new_acc = update_in(acc[address][:pairs], &check_merge(&1, new))

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "update_in/3",
      target: address
    )

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

      {:error, _} ->
        format_error({:error, {f_index, f_type, f_char}}, list)
    end
  end

  defp starts_with_bracket?(index, type, char, node) when type == :open_bracket and char == "{" do
    {:ok, %{type: "Object", start: index, end: nil, pairs: [], address: node}}
  end

  defp starts_with_bracket?(index, _type, _char, node) do
    {:error, %{type: "Improper object", start: index, end: nil, pairs: [], address: node}}
  end

  defp ends_with_bracket?(index, type, char, acc, node)
       when type == :close_bracket and char == "}" do
    %{acc | address: node, end: index}
  end

  defp ends_with_bracket?(index, _type, _char, acc, _node) do
    %{acc | type: "Improper object", end: index}
  end

  # Rules for evaluating the keys.
  defguard is_string(first, second, third)
           when elem(elem(first, 1), 0) == :quote and
                  elem(elem(second, 1), 0) == :string and
                  elem(elem(third, 1), 0) == :quote

  defguardp is_start_of_string(first, second)
            when elem(elem(first, 1), 0) == :quote and
                   elem(elem(second, 1), 0) == :string

  defguardp is_start_of_unquoted_string(first)
            when elem(elem(first, 1), 0) == :string

  defguardp is_colon(token)
            when elem(elem(token, 1), 0) == :colon

  defguardp is_unquoted_string(first)
            when elem(elem(first, 1), 0) == :string 

  defguardp is_bool(first)
            when elem(elem(first, 1), 0) == true or
                   elem(elem(first, 1), 0) == false or
                   elem(elem(first, 1), 0) == :null
 
  defguardp is_whitespace(first) when elem(elem(first, 1), 0) == :empty_string

  defguard is_escape(token) when elem(elem(token, 1), 0) == :escape

  defp get_key([first, second, third | tail] = _list) when is_string(first, second, third) do
    string = get_val(second)
    {tail, "\"#{string}\""}
  end

  defp get_key([first, second | _tail] = list) when is_start_of_string(first, second) do
    get_end_of_proper_string(list)
  end

  # Get the key if string is not wrapped by quotes
  defp get_key([first | tail] = _list) when is_unquoted_string(first) do
    string = get_val(first)
    {tail, "\"" <> string <> "\""}
  end

  defp get_key([first | tail] = _list) do
    Logger.info("ignoring key #{inspect(first)}") 
    get_key(tail)
  end

  # Rules for evaluating values.
  defguard is_comma(token) when elem(elem(token, 1), 0) == :comma


  defguard is_comma_or_bracket(token)
           when elem(elem(token, 1), 0) == :comma or
                  elem(elem(token, 1), 0) in [:close_bracket, :open_bracket]

  defguardp is_int(first)
            when elem(elem(first, 1), 0) == :int

  defguardp is_node_slot(first, second)
            when is_colon(first) and
                   elem(first, 0) + 2 < elem(second, 0) and
                   is_comma_or_bracket(second)

  defguardp is_empty_string(first, second)
            when elem(elem(first, 1), 0) == :quote and
                   elem(elem(second, 1), 0) == :quote

  defguardp is_value_list(first)
            when elem(elem(first, 1), 0) == :open_square

  defguardp is_final_element(first)
            when elem(elem(first, 1), 0) == :close_square

  # unwrap the tuple
  defp get_value({list, key} = _tuple) do
    Enum.reject(list, fn t -> elem(elem(t, 1), 0) == :empty_string end)
    |> get_value(key)
  end

  # basic logic check (is this a correctly formatted value?)
  defp get_value([first, second | _tail] = list, key) when is_node_slot(first, second) do
    {:insert_node, list, key}
  end

  defp get_value([first | new_list] = _list, key) when is_colon(first) do
    evaluate_value_type(new_list, key)
  end

  defp get_value([first | new_list] = _list, key) when is_comma_or_bracket(first) do
    evaluate_value_type(new_list, key)
  end

  # Idea here is to move forward in case of no pattern recognized. 
  # This approach is easier than ignoring all the escapes and 
  # other weird stuff manually, but does come with the cost of 
  # potentially ignoring what the algorithm needs to catch.
  defp get_value([first | tail] = _list, key) do
    Logger.info("ignoring value #{inspect(first)}") 
    get_value(tail, key)
  end

  # format detection rules
  defp evaluate_value_type([first | tail] = _list, key) when is_int(first) do
    int = get_val(first)
    {tail, %{key => int}}
  end

  defp evaluate_value_type([first | new_list] = _list, key) when is_value_list(first) do
    {:start_list, new_list, key}
  end

  defp evaluate_value_type(list, key) when list == [] do
    {:insert_node, list, key}
  end

  defp evaluate_value_type([first, second, third | tail] = _list, key)
       when is_string(first, second, third) do
    string = get_val(second)
    {tail, %{key => "\"#{string}\""}}
  end

  defp evaluate_value_type([first | tail] = list, key)
       when is_start_of_unquoted_string(first) do
       Logger.info([key: key, list: list], ansi_color: :red)
    {new_tail, string} = get_end_of_unquoted_string([first | tail])
    {new_tail, %{key => "\"#{string}\""}}
  end

  defp evaluate_value_type([first, second, third | tail] = _list, key)
       when is_empty_string(first, second) and is_comma(third) do
    {List.flatten([[third], [tail]]), %{key => ""}}
  end

  defp evaluate_value_type([first, second | _tail] = list, key)
       when is_start_of_string(first, second) do
    {new_tail, val} = get_end_of_proper_string(list)
    {new_tail, %{key => val}}
  end

  defp evaluate_value_type(list, key) when list == [] do
    {:insert_node, list, key}
  end

  defp evaluate_value_type([first | _tail] = list, key)
       when is_start_of_unquoted_string(first) do
    {new_tail, val} = get_end_of_unquoted_string([first | list])
    {new_tail, %{key => val}}
  end

  defp evaluate_value_type([first | tail] = _list, key) when is_bool(first) do
    {tail, %{key => get_val(first)}}
  end

  # Catch-all case: remove the unrecognized pattern and move forward. 
  # Most of what falls here should be whitespace, escapes, etc.  
  defp evaluate_value_type([_first | tail] = _list, key) do
    evaluate_value_type(tail, key)
  end

  # if the value is a node
  defp maybe_insert_node({command, [first, second | tail] = list, key} = _tuple, acc, address)
       when command == :insert_node and list != [] do
    start = elem(first, 0)
    finish = elem(second, 0)

    full_address = get_in(acc[address], [:address])

    case correct?(start, finish, acc, address) do
      :ok ->
        child =
          Map.reject(acc, fn {k, v} ->
            k == address ||
              (v[:address] == full_address &&
                 v[:address] -- [k] == full_address)
          end)
          |> Map.keys()
          |> List.first()

        key_val = %{key => acc[child].pairs}

        new_acc = Map.reject(acc, fn {k, _v} -> k == child end)

        {tail, key_val, new_acc}

      :error ->
        {list, key, acc}
    end
  end

  defp maybe_insert_node({command, list, key} = _tuple, prev_acc, address)
       when command == :insert_node and list == [] do
    full_address = get_in(prev_acc[address], [:address])

    child = get_children(prev_acc, address)

    if is_list(child) do
      last =
        Enum.sort(child)
        |> List.first()

      key_val = %{key => prev_acc[last].pairs}

      new_acc = Map.reject(prev_acc, fn {k, _v} -> k == last end)

      Logger.debug(
        source: "[" <> Path.basename(__ENV__.file) <> "]",
        message: "inserted node",
        target: full_address,
        inserted: last
      )

      {[], key_val, new_acc}
    else
      key_val = %{key => prev_acc[child].pairs}

      new_acc = Map.reject(prev_acc, fn {k, _v} -> k == child end)

      Logger.debug(
        source: "[" <> Path.basename(__ENV__.file) <> "]",
        message: "inserted node",
        target: full_address,
        inserted: child
      )

      {[], key_val, new_acc}
    end
  end

  defp maybe_insert_node({list, key} = _tuple, acc, _address) do
    {list, key, acc}
  end

  # Rules for inserting elements in a list. They are a bit tricky cause
  # you can have anything in them, including key-value pairs.
  defp maybe_insert_node(
         {command, [_first | tail] = _list, key} = _tuple,
         prev_acc,
         address
       )
       when command == :start_list do
    final_index = get_final_square(tail)

    list_elements =
      Enum.reject(tail, fn t ->
        elem(t, 0) > final_index ||
          elem(elem(t, 1), 0) == :close_bracket ||
          elem(elem(t, 1), 0) == :empty_string
      end)

    new_tail =
      Enum.filter(tail, fn t ->
        elem(t, 0) > final_index
      end)

    maybe_insert_node({:cont_list, list_elements, key}, prev_acc, address, new_tail)
  end

  defp maybe_insert_node({:cont_list, elements, key}, acc, address, new_tail) do
    {new_acc, remaining_elements} = insert_into_list(acc, elements, address, key)

    if remaining_elements != [] do
      maybe_insert_node({:cont_list, remaining_elements, key}, new_acc, address, new_tail)
    else
      maybe_insert_node({:end_list, remaining_elements, key}, new_acc, address, new_tail)
    end
  end

  defp maybe_insert_node({:end_list, elements, _key}, acc, _address, new_tail)
       when elements == [] do
    {new_tail, nil, acc}
  end

  # Rules for inserting values into a list
  defp insert_into_list(
         prev_acc,
         [first, second, third | tail] = _list_elements,
         address,
         key
       )
       when is_string(first, second, third) do
    old_pair = get_key_values(prev_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)
    val = elem(elem(second, 1), 1)

    conditional_insert(non_key, old_pair, val, prev_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first, second | tail] = _list_elements,
         address,
         key
       )
       when is_int(first) and is_comma(second) do
    old_pair = get_key_values(prev_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)
    val = elem(elem(first, 1), 1)

    conditional_insert(non_key, old_pair, val, prev_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first, second | tail] = _list_elements,
         address,
         key
       )
       when is_int(first) and is_comma(second) do
    old_pair = get_key_values(prev_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)
    val = elem(elem(first, 1), 1)

    conditional_insert(non_key, old_pair, val, prev_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first, second | tail] = _list_elements,
         address,
         key
       )
       when is_bool(first) and is_comma(second) do
    old_pair = get_key_values(prev_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)

    val = elem(elem(first, 1), 1)

    conditional_insert(non_key, old_pair, val, prev_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first, second | tail] = _list_elements,
         address,
         key
       )
       when is_bool(first) and is_comma(second) do
    old_pair = get_key_values(prev_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)
    val = elem(elem(first, 1), 1)

    conditional_insert(non_key, old_pair, val, prev_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first | tail] = _list_elements,
         address,
         key
       )
       when is_comma(first) do
    {_, key_val, new_acc} = maybe_insert_node({:insert_node, [], key}, prev_acc, address)

    key_val = maybe_merge_maps(key_val, key)
    old_pair = get_key_values(new_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)

    conditional_insert(non_key, old_pair, key_val, new_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first | tail] = _list_elements,
         address,
         key
       )
       when is_final_element(first) and
              tail == [] do
    {_, key_val, new_acc} = maybe_insert_node({:insert_node, [], key}, prev_acc, address)

    key_val = maybe_merge_maps(key_val, key)
    old_pair = get_key_values(new_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)

    conditional_insert(non_key, old_pair, key_val, new_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first | tail] = _list_elements,
         address,
         key
       )
       when is_comma(first) do
    {_, key_val, new_acc} = maybe_insert_node({:insert_node, [], key}, prev_acc, address)

    key_val = maybe_merge_maps(key_val, key)
    old_pair = get_key_values(new_acc, address, key)
    non_key = get_non_key_values(prev_acc, address, key)

    conditional_insert(non_key, old_pair, key_val, new_acc, address, key, tail)
  end

  defp insert_into_list(
         prev_acc,
         [first | tail] = _list_elements,
         _address,
         _key
       )
       when is_whitespace(first) do
    {prev_acc, tail}
  end

  defp conditional_insert(non_key, old_pair, val, acc, address, key, tail)
       when old_pair == nil and
              non_key == nil do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      message: "starting new list with a new node and no other key value pairs",
      non_key: non_key,
      new_val: val
    )

    complete_acc = put_in(acc[address][:pairs], [%{key => [val]}])
    {complete_acc, tail}
  end

  defp conditional_insert(non_key, old_pair, val, acc, address, key, tail)
       when old_pair == nil and
              non_key != nil do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      message: "starting new list with a new node and non related key value pairs",
      non_key: non_key,
      new_val: val
    )

    complete_acc = put_in(acc[address][:pairs], [non_key, %{key => [val]}])
    {complete_acc, tail}
  end

  defp conditional_insert(non_key, old_pair, val, acc, address, key, tail)
       when old_pair != nil and
              non_key == nil do
    new_val = List.flatten([old_pair[key]], [val])

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      message: "adding value to previously existing list with no other key value pairs",
      non_key: non_key,
      new_val: new_val
    )

    complete_acc = put_in(acc[address][:pairs], [%{key => [new_val]}])
    {complete_acc, tail}
  end

  defp conditional_insert(non_key, old_pair, val, acc, address, key, tail)
       when old_pair != nil and
              non_key != nil do
    new_val = List.flatten([old_pair[key]], [val])

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      message: "starting new list with a new node and non related key value pairs",
      non_key: non_key,
      new_val: new_val
    )

    complete_acc = put_in(acc[address][:pairs], [non_key, %{key => [new_val]}])
    {complete_acc, tail}
  end

  defp maybe_merge_maps(map, key) do
    keys = Map.get(map, key)

    if keys != nil do
      Enum.reduce(keys, %{}, fn k, acc ->
        Map.merge(acc, k)
      end)
    else
      map
    end
  end

  defp get_key_values(acc, address, key) do
    value = get_in(acc[address][:pairs])

    if value == nil do
      nil
    else
      Enum.find(value, fn m -> Map.keys(m) == [key] end)
    end
  end

  defp get_non_key_values(acc, address, key) do
    get_in(acc[address][:pairs])
    |> Enum.find(fn m -> Map.keys(m) != [key] end)
  end

  # Rules for evaluating separation of key-value pairs or other elements
  defp get_separator({list, key_val, acc} = _tuple) do
    get_separator(list, key_val, acc)
  end

  defp get_separator([first | tail] = _list, key_val, acc) when is_comma(first) do
    {tail, key_val, acc}
  end

  defp get_separator(list, key_val, acc) when list == [] and is_map(key_val) do
    {[], key_val, acc}
  end

  defp get_separator(list, key_val, acc) when list == [] and not is_map(key_val) do
    {[], nil, acc}
  end

  defp get_separator([first | tail] = _list, key_val, acc)
       when tail != [] and is_map(key_val) and not is_comma(first) do
    get_separator({tail, key_val, acc})
  end

  defp get_separator([first | tail] = _list, key_val, acc) do
    Logger.info("ignoring value #{inspect(first)}")
    get_separator(tail, key_val, acc)
  end

  # Helper functions
  defp get_end_of_proper_string([first, second | tail] = list)
       when elem(elem(first, 1), 0) == :quote do
       Logger.info(tail)
    {end_index, _} = List.keyfind(tail, {:quote, "\""}, 1) || List.last(tail)
    {start_index, _} = second

    string =
      Enum.filter(list, fn {i, _val} -> i >= start_index && i < end_index end)
      |> Enum.reduce([], fn v, acc -> acc ++ [get_val(v)] end)
      |> Enum.join("")

    new_tail = Enum.reject(list, fn {i, _v} -> i < end_index + 1 end)
    {new_tail, "\"#{string}\""}
  end

  defp get_children(prev_acc, address) do
    full_address = get_in(prev_acc[address], [:address])

    Enum.reduce(prev_acc, [], fn {k, _v}, acc ->
      {child, parent} = List.pop_at(get_in(prev_acc[k], [:address]), -1)

      if parent == full_address do
        acc = check_merge(acc, child)
        acc
      else
        acc
      end
    end)
  end
 
  # handles a multi-word string, which means this needs to iterate the tail until it finds a 
  # thing that is not a string - please note that whitespace is already excluded by this point
  # as it would break other parts of the generator
  defp get_end_of_unquoted_string([first, second | tail] = list)
       when elem(elem(first, 1), 0) == :string and
              elem(elem(second, 1), 0) == :string and
              tail != [] do
    {end_index, _tuple} = Enum.reject(tail, fn t -> get_type(t) == :string end) |> List.first()
    {start_index, _} = second

    string =
      Enum.filter(list, fn {i, _val} -> i >= start_index && i < end_index end)
      |> Enum.reduce([], fn v, acc -> acc ++ [get_val(v)] end)
      |> Enum.join(" ")

    new_tail = Enum.reject(list, fn {i, _v} -> i < end_index end)
    {new_tail, string}
  end

  # handles a one-word string that immediately ends in a comma. meaning no iteration needed
  defp get_end_of_unquoted_string([first, second | tail] = _list)
       when elem(elem(first, 1), 0) == :string
       and elem(elem(second, 1), 0) == :comma
       and tail != [] do
    {List.flatten([second, tail]), "#{get_val(first)}"}
  end

  # handles end of doc unquoted string, which would fail previous checks
  defp get_end_of_unquoted_string([first | tail] = _list)
       when elem(elem(first, 1), 0) == :string
       and tail == [] do
    {[], "#{get_val(first)}"}
  end

  defp correct?(start, finish, acc, address) do
    node_start = acc[address].start
    node_end = acc[address].end

    if start + 1 > node_start && finish - 1 < node_end do
      :ok
    else
      Logger.error(%{
        source: "[" <> Path.basename(__ENV__.file) <> "]",
        message: "Got a wrong call node insertion request",
        address: address,
        requested_start_index: node_start,
        requested_start_end: node_end,
        actual_start: start,
        actual_end: finish
      })

      :error
    end
  end

  defp get_val(tuple) do
    elem(elem(tuple, 1), 1)
  end

  defp get_type(tuple) do
    elem(elem(tuple, 1), 0)
  end

  defp check_merge(old, new) when old == [] or old == nil do
    new
  end

  defp check_merge(old, new) when new == [] or new == nil do
    old
  end

  defp check_merge(old, new) do
    List.flatten([[old], [new]])
  end

  defp get_final_square(tail) do
    final =
      Enum.filter(tail, fn t ->
        elem(elem(t, 1), 0) == :close_square
      end)

    cond do
      length(final) > 1 ->
        List.keysort(final, 0)
        |> List.first()
        |> elem(0)

      length(final) == 1 ->
        [tuple] = final
        elem(tuple, 0)

      true ->
        {index, _} = List.last(tail)
        f_index = index + 1
        {f_index, {:close_square, "]"}}
    end
  end

  # Error formatting
  defp format_error({status, {index, message, char}} = _tuple, list)
       when status == :error and index < 5 do
    preview = make_preview(list, index, 3)
    {:error, "#{message}: #{preview}", char}
  end

  defp format_error({status, {index, message, char}} = _tuple, list)
       when status == :error and index >= 5 do
    preview = make_preview(list, index, 5)
    {:error, "#{message}: #{preview}", char}
  end

  defp format_error({_status, {index, message, char}} = _tuple, list) do
    preview = make_preview(list, index, 3)

    Logger.error(%{
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      message: "non-error passed to error handler",
      params: [
        err_message: message,
        preview: preview,
        index: index,
        char: char
      ]
    })

    {:error, preview, char}
  end

  defp make_preview(list, index, c_range) do
    Enum.filter(list, fn {indexes, {_types, _chars}} ->
      indexes < index - c_range && indexes > index + c_range
    end)
    |> Enum.map_join(fn {_indexes, {_type, char}} -> char end)
  end
end
