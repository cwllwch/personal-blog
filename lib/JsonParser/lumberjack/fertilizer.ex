defmodule JsonParser.Lumberjack.Fertilizer do
  @moduledoc """
  This adds content from tokens to the nodes based 
  on the tree structure returned by TreeBuilder. 
  Returns a tuple with a map with content and a list 
  of addresses to the nodes in the map for convenience. 
  """

  require Logger

  defguardp are_siblings?(node1, node2, diff) when length(node1) == length(node2) and node1 != node2 and length(diff) == 1
  
  def main(tree, addresses, tokens) do
    get_checkpoints(tree, addresses)
    |> fill_intermediaries
    |> insert_content(tree, tokens)
  end
 
  def get_checkpoints(tree, addresses) do
     startpoints = 
     Enum.reduce(addresses, [], fn node, acc -> 
      start = 
        get_in(tree, node)
        |> Map.get(:beginning)

        acc ++ [{node, start}]
      end
    )

    endpoints = Enum.reduce(addresses, [], fn node, acc -> 
      ending = 
        get_in(tree, node)
        |> Map.get(:end)

        acc ++ [{node, ending}]
      end
    )

    startpoints ++ endpoints
    |> List.keysort(1)
  end



  defp fill_intermediaries(og_list) do 
    {first_tuple, new_list} = List.pop_at(og_list, 0)
    {second_tuple, _} = List.pop_at(new_list, 0)

    node1 = elem(first_tuple, 0)
    node2 = elem(second_tuple, 0)
    diff = node1 -- node2
    
    check_necessity(node1, node2, diff, og_list)
    |> fill_intermediaries(new_list)
  end

  defp fill_intermediaries(acc, list) when length(list) > 1 do
    {node1, new_list} = List.pop_at(list, 0)
    {node2, _} = List.pop_at(new_list, 0)

    diff = elem(node2, 0) -- elem(node1, 0)

    check_necessity(node1, node2, diff, acc)
    |> fill_intermediaries(new_list)
  end

  defp fill_intermediaries(acc, list) when length(list) <= 1, do: (if length(acc) > length(list), do: acc, else: list)


  defp check_necessity(node1, node2, diff, list) when are_siblings?(elem(node1, 0), elem(node2, 0), diff) do
    difference = elem(node2, 1) - elem(node1, 1)
    if difference >= 1 do
      parent = List.delete_at(elem(node2, 0), -1)
      
      new_tuple1 = {parent, elem(node1, 1) + 1}
      new_tuple2 = {parent, elem(node2, 1) - 1}

      [list, new_tuple1, new_tuple2] 
      |> List.flatten()
      |> List.keysort(1)

    else
      list  
   end
  end

  defp check_necessity(_node1, _node2, _diff, list) do 
    list
  end


  defp insert_content(list, tree, tokens) when length(list) > 1 do
    {first_pointer, new_list} = List.pop_at(list, 0)
    {second_pointer, _} =  List.pop_at(new_list, 0)

    acc = evaluate_iterate(first_pointer, second_pointer, tokens, tree)

    insert_content(new_list, acc, tokens)
  end

  defp insert_content([_head | tails ] = _list, tree, _tokens) when tails == [], do: tree

  defp evaluate_iterate(start, finish, tokens, tree) do
    {node1, start_index} = start
    {node2, finish_index} = finish 

    cond do 
    length(node1) < length(node2) ->
      finish_index = finish_index - 1
      Logger.debug(%{
        message: "adding from #{start_index} to #{finish_index} into", 
        node_added: node1, 
        node_ignored: node2})
      iterate(node1, start_index, finish_index, tokens, tree)
    length(node1) == length(node2) && node1 != node2 ->
      finish_index = finish_index - 1
      Logger.debug(%{
        message: "adding from #{start_index} to #{finish_index} into", 
        node_added: node1, 
        node_ignored: node2})
      iterate(node1, start_index, finish_index, tokens, tree)
    node1 == node2 ->
      finish_index = finish_index
      Logger.debug(%{
        message: "adding from #{start_index} to #{finish_index} into", 
        node_added: node1, 
        node_ignored: node2})
      iterate(node1, start_index, finish_index, tokens, tree)
    length(node1) > length(node2) ->
      finish_index = finish_index - 1
      Logger.debug(%{
        message: "adding from #{start_index} to #{finish_index} into", 
        node_added: node2, 
        node_ignored: node1})
      iterate(node2, start_index, finish_index, tokens, tree)
    end
  end

  defp iterate(address, start, finish, tokens, tree) do
    range = start..finish
    content = 
    Enum.reduce(range, %{}, 
      fn index, acc ->
        to_add = List.keyfind!(tokens, index, 0) 
        Map.put_new(acc, index, {elem(to_add, 1), elem(to_add, 2)})
      end)
    |> Enum.sort

    {_, new_tree} = get_and_update_in(tree, List.flatten([address, :content]), &(nil_killer(&1, content)))
    new_tree 
  end

  defp nil_killer(previous_content, new_content) do
    if previous_content == nil do
      {:ok, new_content}
    else
      filtered = List.flatten([previous_content, new_content])
      |> Enum.dedup()
      {:ok, filtered}  
    end
  end
end
