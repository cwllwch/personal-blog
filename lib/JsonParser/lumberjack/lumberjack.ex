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

  @spec main(list(tuple())) :: {:ok, map(), list()} | {:error, String.t()}
  def main(tokens) when tokens != [] do
    start = Time.utc_now()

    case TreeBuilder.main(tokens) do
      {:ok, tree, nodes} ->
        result =
          Fertilizer.main(tree, nodes, tokens)
          |> NodeProcessor.main(nodes)

        finish = Time.utc_now()
        # get with high precision but convert to ms
        diff = Time.diff(finish, start, :microsecond) / 1_000

        Logger.info([
          source: "[" <> Path.basename(__ENV__.file) <> "]",
          processing_time_ms: diff,
          token_length: length(tokens),
          nodes: length(nodes),
          map_depth: List.last(nodes) |> length(),
          total_memory_mb: :erlang.memory(:total) / 1_000_000,
          process_memory_mb: elem(:erlang.process_info(self(), :memory), 1) / 1_000_000
          ],
        ansi_color: :green
        )

        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  def main(tokens) when tokens == [] do
    {:error, "empty list"}
  end
end
