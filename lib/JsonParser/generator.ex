defmodule JsonParser.Generator do
  @moduledoc """
  This module will take the AST from the previous bit and 
  output an actual valid JSON string. It takes in a map 
  that contains lists and other maps, and will output a 
  valid JSON encoded string - which will then be passed
  to JSON.encode! for validation and prettifying - which
  is the bit I can't be arsed to do myself. 
  """

  @doc """
  Receives a map of keys and values which can 
  be strings, numbers or lists, and outputs a
  valid JSON-encoded string.
  """

  require Logger

  @spec main(map()) :: {:ok, bitstring()} | {:error, binary()}
  def main(ast) do
    result = "{" <> orchestrate(ast) <> "\n}"
    {:ok, result}
  rescue
    e in [ArgumentError] ->
      {:error, "argument: " <> Exception.message(e)}

    e ->
      [{module, function, arity, meta} | _] = __STACKTRACE__

      Logger.warning(
        message: "unhandled exception",
        exception: Exception.message(e),
        mfa: "#{module} - #{function}, arguments given: #{inspect(arity)}",
        location: inspect(meta[:file]) <> " at " <> inspect(meta[:line])
      )

      {:error, "Error generating string: #{Exception.message(e)}"}
  end

  ## Orchestrate the iteration of getting keys and values.
  defp orchestrate(ast) when is_map(ast) do
    keys = get_key(ast)

    orchestrate(ast, keys)
  end

  defp orchestrate([head | tail] = _list) when tail == [] do
    orchestrate(head, get_key(head))
  end

  defp orchestrate([head | tail] = _list) when tail != [] and is_map(head) do
    keys = get_key(head)

    acc = "#{keys}: #{get_val(head, keys)}"

    orchestrate(tail, acc)
  end

  # starts an accumulator for lists of maps
  defp orchestrate([head | tail] = _list) when tail != [] and is_map(head) do
    keys =
      get_key(head)
      |> List.first()

    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      function: "orchestrate/1",
      condition: "found a list of keywords at the start",
      key: keys
    )

    acc = orchestrate(head, keys)

    orchestrate(tail, acc)
  end

  defp orchestrate([head | tail] = _list, acc) when head != [] do
    key = get_key(head)

    new_acc = "#{acc},\n #{orchestrate(head, key)}"

    orchestrate(tail, new_acc)
  end

  defp orchestrate(list, acc) when list == [] do
    acc
  end

  # returns in case of just one map
  defp orchestrate(map, keys) when length(keys) == 1 and is_map(map) do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found single key at the start",
      key: List.first(keys)
    )

    val = get_val(map, keys)
    "#{List.first(keys)}: #{val}"
  end

  defp orchestrate(val, keys) when is_binary(val) and keys == val do
    val
  end

  # starts the accumulator for a list of maps
  defp orchestrate(map, keys) when length(keys) > 1 do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start",
      key: List.first(keys)
    )

    [key | remaining] = keys
    val = get_val(map, [key])

    acc = "#{key}: #{val}"

    new_map = Map.reject(map, fn {k, _v} -> String.contains?(k, key) end)

    orchestrate(new_map, remaining, acc)
  end

  defp orchestrate(map, [first | tail] = keys, acc) when keys != [] and tail != [] do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start and will accumulate results",
      key: first
    )

    val = get_val(map, [first])

    new_acc = "#{acc} \n#{first}: #{val}"

    new_map = Map.reject(map, fn {k, _v} -> String.contains?(k, first) end)

    orchestrate(new_map, tail, new_acc)
  end

  defp orchestrate(map, [first | tail] = keys, acc) when keys != [] and tail == [] do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start, ending accumulation of objects",
      key: first
    )

    val = get_val(map, [first])

    new_acc = "#{acc} \n#{first}: #{val}"

    orchestrate(map, tail, new_acc)
  end

  # returns after processing the list of maps
  defp orchestrate(_map, keys, acc) when keys == [] do
    acc
  end

  ## Key logic

  # when there is just one key but many vals
  defp get_key(key) when is_map(key) do
    Map.keys(key)
  end

  # single key
  defp get_key(key) when is_binary(key) do
    key
  end

  ## Value logic
  defp get_val(map, key) when is_map(map) do
    get_in(map, key)
    |> process_val()
  end

  # This means the value is a list of values
  defp process_val([head | _tail] = _val) when is_list(head) do
    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a list of values"
    )

    "[" <>
      Enum.reduce(head, ", ", fn m, acc -> orchestrate(m) |> add_brackets() |> append(acc) end) <>
      "\n]"
  end

  defp process_val([head | tail] = _val) when is_map(head) and tail == [] do
    Logger.debug(source: "[#{Path.basename(__ENV__.file)}]", message: "found a map", head: head)
    "{#{orchestrate(head)}}"
  end

  defp process_val([head | tail] = val) when is_map(head) and tail != [] do
    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a list of maps"
    )

    "{" <> Enum.reduce(val, "", fn m, acc -> orchestrate(m) |> append(acc) end) <> "}"
  end

  defp process_val(val) when is_binary(val) do
    val
  end

  # Helpers

  ## This is just for appending values when they both exist, otherwise Enum above would just delete previous acc
  ## when hitting it
  @spec append(String.t(), String.t()) :: String.t()
  defp append(new, old) when old == "" do
    new
  end

  @spec append(String.t(), String.t()) :: String.t()
  defp append(new, old) when new == "" do
    old
  end

  @spec append(String.t(), String.t()) :: String.t()
  defp append(new, old) do
    "\n#{old},\n #{new}"
  end

  ## add brackets to separate when needed
  defp add_brackets(string) do
    "{#{string}}"
  end
end
