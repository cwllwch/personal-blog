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

  @spec main(map()) :: String.t()
  def main(ast) do
    orchestrate(ast)
  end

  ## Orchestrate the iteration of getting keys and values.

  defp orchestrate(ast) do
    keys = get_key(ast)

    orchestrate(ast, keys)
  end

  defp orchestrate(map, keys) when length(keys) == 1 and is_map(map) do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found single key at the start",
      key: List.first(keys)
    )

    val = get_val(map, keys)
    "{#{List.first(keys)}: #{val}}"
  end

  defp orchestrate(val, keys) when is_binary(val) and keys == val do
    val
  end

  defp orchestrate(map, keys) when length(keys) > 1 do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start",
      key: List.first(keys)
    )

    [key | remaining] = keys
    val = get_val(map, [key])

    acc = "{#{key}: #{val}} \n"

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

    new_acc = "#{acc} {#{first}: #{val}}"

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

    new_acc = "#{acc} {#{first}: #{val}}"

    orchestrate(map, tail, new_acc)
  end

  defp orchestrate(_map, keys, acc) when keys == [] do
    acc
  end

  ## Key logic
  defp get_key(key) when is_map(key) do
    Map.keys(key)
  end

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
    Logger.debug("found a list of values")
    "\n[" <> Enum.reduce(head, "", fn m, acc -> orchestrate(m) |> append(acc) end) <> "\n]"
  end

  defp process_val(val) when is_list(val) and length(val) > 1 do
    Logger.debug("found a list of maps")
    Enum.reduce(val, "", fn m, acc -> orchestrate(m) |> append(acc) end)
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
    "#{old}, #{new}"
  end
end
