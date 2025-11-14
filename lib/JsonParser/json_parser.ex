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
        Jason.encode!(parsed, pretty: true)

      {:error, reason} ->
        Logger.info(reason)
        parse_this(json)
    end
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
