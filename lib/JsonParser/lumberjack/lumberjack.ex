defmodule JsonParser.Lumberjack do
  @moduledoc """
  This module takes a list of tokens and returns an Abstract Syntax
  Tree in json.
  Should be the second intermediary step between getting the bad
  json and outputting where it needs to be corrected, which will
  allow us to evaluate the tree with rules and transform it.
  """
  alias JsonParser.Lumberjack.TreeBuilder
  alias JsonParser.Lumberjack.Fertilizer
  alias JsonParser.Lumberjack.NodeProcessor


  @spec main(list(tuple())) :: {:ok, map(), list()} | {:error, String.t()}
  def main(tokens) when tokens != [] do

    case TreeBuilder.main(tokens) do

      {:ok, tree, nodes} ->
        Fertilizer.main(tree, nodes, tokens)
        |> NodeProcessor.main(nodes)
      {:error, reason} -> 
        {:error, reason}
    end
  end

  def main(tokens) when tokens == [] do
    {:error, "empty list"}
  end
end
