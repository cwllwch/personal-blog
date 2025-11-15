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
    result =
      Tokenizer.main(not_json)
      |> Lumberjack.main()
      |> Generator.main()

    if result do
      Jason.Formatter.pretty_print(result)
    else
      "Error: #{result}"
    end
  end
end
