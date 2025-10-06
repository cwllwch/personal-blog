defmodule JsonParser.Lumberjack do
  
  @moduledoc """
  This module takes a list of tokens and returns an Abstract Syntax
  Tree in json.
  Should be the second intermediary step between getting the bad
  json and outputting where it needs to be corrected, which will
  allow us to evaluate the tree with rules and transform it.
  """
  require Logger
  
  @spec main(list(tuple())) :: {:ok, map()} | {:error, String.t()}
  def main(tokens) when tokens != [] do
    tree = find_brackets(tokens)
    |> get_tree_struct()
  #  |> add_contents(tokens)
    tree
  end

  def main(tokens) when tokens == [] do
    {:error, "empty list"}
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
      {:ok, new_acc}
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

  #defp add_contents(tree, tokens) do
  #bracketless = Enum.filter(tokens, 
  #  fn char -> elem(char, 1) != :open_bracket || elem(char, 1) != :close_bracket 
  #end)
    
  #nodes = get_tree_struct(tree)
  #end

  def get_tree_struct(tree) do
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
  

  def add_nodes(path, key) when length(key) >= 1 do
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
