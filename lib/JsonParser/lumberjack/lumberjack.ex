defmodule JsonParser.Lumberjack do
  @moduledoc """
  This module takes a list of tokens and returns an Abstract Syntax
  Tree in json.
  Should be the second intermediary step between getting the bad
  json and outputting where it needs to be corrected, which will
  allow us to evaluate the tree with rules and transform it.
  """
  alias JsonParser.Lumberjack.Fertilizer
  alias JsonParser.Lumberjack.NodeProcessor
  alias JsonParser.Lumberjack.TreeBuilder

  require Logger

  @spec main(list(tuple())) :: {:ok, map()} | {:error, String.t()}
  def main(tokens) when tokens != [] do
    start = Time.utc_now()
    mem_before = elem(:erlang.process_info(self(), :memory), 1) / 1_000_000

    with {:ok, tree, nodes} <- TreeBuilder.main(tokens),
         {:ok, pre_ast} <- Fertilizer.main(tree, nodes, tokens),
         {:ok, result} <- NodeProcessor.main(pre_ast, nodes) 
      do
      Logger.info([nodes: pre_ast], ansi_color: :red)
        # Log metrics and info
        finish = Time.utc_now()
        diff = Time.diff(finish, start, :microsecond) / 1_000
        Logger.info(
          [
            source: "[" <> Path.basename(__ENV__.file) <> "]",
            processing_time_ms: diff,
            token_length: length(tokens),
            nodes: length(nodes),
            map_depth: List.last(nodes) |> length(),
            total_memory_mb: :erlang.memory(:total) / 1_000_000,
            process_memory_before: mem_before,
            process_memory_after_mb: elem(:erlang.process_info(self(), :memory), 1) / 1_000_000
          ], ansi_color: :green
        )
       {:ok, result}
    else
      {:error, error} -> 
        {:error, error}
    end
  end

  def main(tokens) when tokens == [] do
    {:error, "empty list"}
  end
end
