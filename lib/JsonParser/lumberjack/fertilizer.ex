defmodule JsonParser.Lumberjack.Fertilizer do
  @moduledoc """
  This adds content from tokens to the nodes based 
  on the tree structure returned by TreeBuilder. 
  Returns a tuple with a map with content and a list 
  of addresses to the nodes in the map for convenience. 
  """

  def main(tree, addresses, tokens) do
    get_checkpoints(tree, addresses)
    |> insert_content(tree, tokens)
  end

  defp get_checkpoints(tree, addresses) do
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

  defp insert_content(list, tree, tokens) do
    {first_pointer, new_list} = List.pop_at(list, 0)
    {second_pointer, _newer_list} =  List.pop_at(new_list, 0)

    iterate(first_pointer, second_pointer, tokens, tree)
  end

  defp iterate(start, finish, tokens, tree) do
    {node, start_index} = start
    {_, finish_index} = finish 

    content = 
    Enum.reduce(start_index..finish_index, %{}, 
      fn index, acc ->
        to_add = List.keyfind!(tokens, index, 0) 
        Map.put_new(acc, "token-#{index}", {elem(to_add, 1), elem(to_add, 2)})
      end)

    get_and_update_in(tree, node, &({:ok, Map.merge(%{content: content}, &1)}))
  end
end
