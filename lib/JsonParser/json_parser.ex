defmodule JsonParser.Main do
  alias Jason
  alias JsonParser.Generator
  alias JsonParser.Lumberjack
  alias JsonParser.Tokenizer
  require String
  require Logger

  @moduledoc """
  This module takes a JSON, checks if it is badly formatted, parses it if it is
  and then returns a prettified version of it.
  """

  def prettify(json) do
    case Jason.decode(json) do
      {:ok, parsed} ->
        result = Jason.encode!(parsed, pretty: true)
        {:ok, result}

      {:error, _reason} ->
        parse_this(json)
        |> handle_result()
    end
  end

  defp handle_result({:ok, result} = _tuple) do
    {:parsed, result}
  end

  defp handle_result({:error, reason} = _tuple) do
    {:error, reason}
  end

  def parse_this(not_json) do
    with {:ok, tokens} <- Tokenizer.main(not_json),
         {:ok, ast} <- Lumberjack.main(tokens),
         {:ok, result} <- Generator.main(ast) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
