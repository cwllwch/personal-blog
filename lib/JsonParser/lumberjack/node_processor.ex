defmodule JsonParser.Lumberjack.NodeProcessor do
  @moduledoc """
  The final step in the AST processing pipeline.
  This module will take the tree and addresses and process each node 
  in order to make them into a proper AST. Now we have a tree with the nodes and 
  contents, this checks for their validity and correctness while building a tree
  that will be later translated to proper json via the Json package itself.
  """

  require Logger

  def main(tree, nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      get_in(tree, List.flatten([node, :content]))
      |> visitor(acc)
    end)
  end

  defp visitor(list, acc) when acc == %{} do
    evaluate_brackets(list)
  end

  defp visitor(_list, acc), do: acc


  defp evaluate_brackets(list) do
    {f_index, {f_type, f_char}} = List.first(list)
    check = starts_with_bracket?(f_index, f_type, f_char)
    case check do
      {:ok, acc} -> 
        {e_index, {e_type, e_char}} = List.last(list)
        ends_with_bracket?(e_index, e_type, e_char, acc)
      {:error, _} -> format_error(check, list)
    end
  end

  defp starts_with_bracket?(index, type, char) when type == :open_bracket and char == "{" do
    {:ok, 
      %{type: "Object", name: "main", body: [
        %{type: type, index: index, char: char}
      ]}
    }
  end

  defp starts_with_bracket?(index, type, char) do
    {:error, 
      %{type: "Improper object", name: "main", body: [
        %{type: type, index: index, char: char}
      ]}
    }
  end


  defp ends_with_bracket?(index, type, char, acc) when type == :close_bracket and char == "}" do
    closer = %{index: index, type: type, char: char}

    %{acc | body: List.insert_at(acc.body, -1, closer)}
  end    


  defp format_error({check, {index, _type, char}} = _tuple, list) when check == :error and index < 5 do
    preview = make_preview(list, index)
    {:error, preview, char}
  end

  defp format_error({_check, {index, type, char}} = _tuple, list) do
    preview = make_preview(list, index)
    
    Logger.error(%{
      message: "non-error passed to error handler",
      params: [
        preview: preview,
        index: index,
        type: type,
        char: char
      ]
    })
    {:error, preview, char}
  end

  defp make_preview(list, index) do
    Enum.filter(list, fn {indexes, {_types, _chars}} -> 
      indexes < index - 3 && indexes > index + 3
      end)
    |> Enum.map_join(fn {_indexes, {_type, char}} -> char end) 
  end
end
