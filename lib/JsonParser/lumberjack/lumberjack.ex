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

  require Logger 


  @spec main(list(tuple())) :: {:ok, map(), list()} | {:error, String.t()}
  def main(tokens) when tokens != [] do
  start = Time.utc_now()
    case TreeBuilder.main(tokens) do
      {:ok, tree, nodes} ->
        result = 
        Fertilizer.main(tree, nodes, tokens)
        |> NodeProcessor.main(nodes)

        finish = Time.utc_now()
        diff = Time.diff(start, finish)
        Logger.info([message: diff])
        
        result 

      {:error, reason} -> 
        {:error, reason}
    end
  end

  def main(tokens) when tokens == [] do
    {:error, "empty list"}
  end
end
