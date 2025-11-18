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

      {:error, reason} ->
        Logger.info(reason)
        result = parse_this(json)
        {:parsed, result}
    end
  end

  def parse_this(not_json) do
    with {:ok, tokens} <- Tokenizer.main(not_json),
         {:ok, ast} <- Lumberjack.main(tokens),
         {:ok, result} <- Generator.main(ast) do
      result
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
