defmodule JsonParser.Lumberjack.TreeBuilder do
  @moduledoc """
  This is a helper module that makes the trees Lumberjack will then fill with content. 
  It returns both the tree based on the positions of the brackets, and a list with node 
  addresses for later use. 
  """

  def main(tokens) do
    try do
      tree = find_brackets(tokens)
      nodes = get_tree_struct(tree)
      {:ok, tree, nodes}
    catch
      error -> {:error, error}
    end
    
  end

  defp find_brackets(tokens) do
    brackets = 
    Enum.filter(tokens, fn char -> 
      elem(char, 1) == :open_bracket || elem(char, 1) == :close_bracket
    end)

    acc = %{}

    process_list(brackets, acc, 0)
  end

  defp process_list(brackets, acc, _level) when brackets == [] do
    acc
  end

  defp process_list(brackets, acc, level) when level == 0 do 
  {token, new_brackets} = List.pop_at(brackets, 0) 
  type = elem(token, 1)
  index = elem(token, 0)

    cond do
    type == :open_bracket ->
      new_acc = put_in(acc, [level], %{beginning: index, parents: nil})
      level = level + 1 
      process_list(new_brackets, new_acc, level, [0], 0)
    type == :close_bracket -> 
      new_acc = get_and_update_in(acc, [level], &({:ok, Map.merge(%{end: index}, &1)}))
      new_acc
    end
  end

  defp process_list(brackets, acc, level, parent, node_id) when level >= 1 do 
  {token, new_brackets} = List.pop_at(brackets, 0)
  type = elem(token, 1)
  index = elem(token, 0)

    cond do
    type == :open_bracket ->
      node_id = node_id + 1
      level = level + 1 
      new_parent = List.insert_at(parent, -1, node_id)
      new_acc = put_in(acc, new_parent, %{parents: parent, beginning: index})
      process_list(new_brackets, new_acc, level, new_parent, node_id)

    type == :close_bracket -> 
      {_, new_acc} = get_and_update_in(acc, parent, &({:ok, Map.merge(%{end: index}, &1)}))
      level = level - 1 
      {_, parent} = List.pop_at(parent, -1)

      if level == 0 do
        process_list(new_brackets, new_acc, level) 
      else
        process_list(new_brackets, new_acc, level, parent, node_id)
      end
    end
  end

  
  defp get_tree_struct(tree) do
    keys = Map.keys(tree)
    |> Enum.filter(&(is_integer(&1)))

    acc = Enum.reduce(keys, [], &(List.insert_at(&2, -1, [&1]))) 
    get_children(tree, acc)
  end

  def get_children(tree, old_acc) do
    keys = Enum.reduce(old_acc, [], fn path, acc -> 
            new = get_in(tree, path)
            |> Map.keys()
            |> Enum.filter(&(is_integer(&1)))

            if new == [] do
              acc
            else
              acc ++ add_nodes(path, new)
            end
          end)

    new_keys = keys -- old_acc

    if new_keys != [] do 
      new_acc = old_acc ++ new_keys
      evaluator(tree, old_acc, new_acc)
    else 
      new_acc = old_acc
      evaluator(tree, old_acc, new_acc)
    end
  end
  

  defp add_nodes(path, key) when length(key) >= 1 do
    Enum.reduce(key, [], fn x, y -> 
        List.insert_at(y, -1, List.flatten([path, x]))
    end)
  end

  def evaluator(tree, acc, new_acc) do
    if acc == new_acc do
      acc
    else
      get_children(tree, new_acc)
    end
  end
end
