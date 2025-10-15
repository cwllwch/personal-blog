defmodule JsonParser.Lumberjack.NodeProcessor do
  @moduledoc """
  The final step in the AST processing pipeline.
  This module will take the tree and addresses and process each node 
  in order to make them into a proper AST. Now we have a tree with the nodes and 
  contents, this checks for their validity and correctness while building a tree
  that will be later translated to proper json via the Json package itself.
  """

  def main(tree, nodes) do
    Enum.reduce(nodes, fn node, acc -> 
      %{acc | "new-node" => node_verifier(tree, node)} 
    end)
  end

  defp node_verifier(tree, address) do
     content = get_in(tree, List.flatten([address, :content]))
     content
  end
end
