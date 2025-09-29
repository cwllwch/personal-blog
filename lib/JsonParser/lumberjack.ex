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
    {:ok, tree}
  end

  def main(tokens) when tokens == [] do
    {:error, "empty list"}
  end

  defp find_brackets(tokens) do
    opens = Enum.filter(tokens, fn char -> elem(char, 1) == :open_bracket end)
    closes = Enum.filter(tokens, fn char -> elem(char, 1) == :close_bracket end)
    
    acc = %{}

    reduce_lists(opens, closes, acc, 0)
  end

  defp reduce_lists(opens, closes, acc, counter) do 
    cond do
      opens == [] and closes == [] -> acc 
      opens != [] and closes != [] ->
        {new_opens, new_closes, new_acc} = iterate(opens, closes, acc, counter)
        counter = counter + 1
        reduce_lists(new_opens, new_closes, new_acc, counter)
    end
  end

  defp iterate(opens, closes, acc, counter) do
    {obj_start, new_opens} =  List.pop_at(opens, 0)
    {obj_end, new_closes} = List.pop_at(closes, -1)
    
    description = %{
      obj_start: obj_start,
      obj_end: obj_end 
       }
    new_acc = Map.put_new(acc, counter, description)
    {new_opens, new_closes, new_acc}
  end
end
