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

  @tab "    "

  @spec main(map()) :: {:ok, bitstring()} | {:error, binary()}
  def main(ast) do
    result = "{\n" <> orchestrate(ast, 1) <> "\n}"
    Logger.info(inspect(ast))
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
  defp orchestrate(ast, counter) when is_map(ast) do
    keys = get_key(ast)

    orchestrate(ast, keys, counter)
  end

  defp orchestrate(string, _counter) when is_binary(string) do
    string
  end

  defp orchestrate([head | tail] = _list, counter) when tail == [] and is_map(head) do
    orchestrate(head, get_key(head), counter)
  end

  defp orchestrate([head | tail] = _list, counter) when tail != [] and is_map(head) do
    keys = get_key(head)

    acc = "#{add_identation(counter)}#{keys}: #{get_val(head, keys, counter)}"

    orchestrate(tail, acc, counter)
  end

  # starts an accumulator for lists of maps
  defp orchestrate([head | tail] = _list, counter) when tail != [] and is_map(head) do
    keys =
      get_key(head)
      |> List.first()

    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      function: "orchestrate/1",
      condition: "found a list of keywords at the start",
      key: keys,
      counter: counter
    )

    acc = orchestrate(head, keys, counter)

    orchestrate(tail, acc, counter)
  end

  defp orchestrate([head | tail] = _list, acc, counter) when head != [] do
    key = get_key(head)

    new_acc = "#{acc},\n#{orchestrate(head, key, counter)}"

    orchestrate(tail, new_acc, counter)
  end

  defp orchestrate(list, acc, _counter) when list == [] do
    acc
  end

  # returns in case of just one map
  defp orchestrate(map, keys, counter) when length(keys) == 1 and is_map(map) do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found single key at the start",
      key: List.first(keys),
      counter: counter
    )

    val = get_val(map, keys, counter)
    add_identation(counter) <> "#{List.first(keys)}: #{val}"
  end

  defp orchestrate(val, keys, _counter) when is_binary(val) and keys == val do
    val
  end

  # starts the accumulator for a list of maps
  defp orchestrate(map, keys, counter) when length(keys) > 1 do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start",
      key: List.first(keys),
      counter: counter
    )

    [key | remaining] = keys
    val = get_val(map, [key], counter)

    acc = "#{key}: #{val}"

    new_map = Map.reject(map, fn {k, _v} -> String.contains?(k, key) end)

    orchestrate(new_map, remaining, acc, counter)
  end

  defp orchestrate(map, [first | tail] = keys, acc, counter) when keys != [] and tail != [] do
    counter = counter + 1

    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start and will accumulate results",
      key: first,
      counter: counter
    )

    val = get_val(map, [first], counter)

    new_acc = "#{acc}\n#{add_identation(counter)}#{first}: #{val}"

    new_map = Map.reject(map, fn {k, _v} -> String.contains?(k, first) end)

    orchestrate(new_map, tail, new_acc, counter)
  end

  defp orchestrate(map, [first | tail] = keys, acc, counter) when keys != [] and tail == [] do
    Logger.debug(
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/2",
      condition: "found multiple keys at the start, ending accumulation of objects",
      key: first,
      counter: counter
    )

    val = get_val(map, [first], counter)

    new_acc = "#{acc}\n#{add_identation(counter)}#{first}: #{val}"

    orchestrate(map, tail, new_acc, counter)
  end

  # returns after processing the list of maps
  defp orchestrate(_map, keys, acc, _counter) when keys == [] do
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
  defp get_val(map, key, counter) when is_map(map) do
    get_in(map, key)
    |> process_val(counter)
  end

  # This means the value is a list of values

  # Looks at first element of the list, if it is a map then it's a key-value pair
  defp process_val(val, counter) when is_map(val) do
    counter = counter + 1

    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a simple map",
      counter: counter
    )

    "{#{orchestrate(val, counter)}\n#{add_identation(counter - 1)}}"
  end

  defp process_val([[head | _t] = inner | _tail] = _val, counter) when is_map(head) do
    counter = counter + 1

    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a list of nested maps",
      counter: counter
    )

    "\n#{add_identation(counter)}[\n" <>
      Enum.reduce(inner, "", fn m, acc ->
        orchestrate(m, 0)
        |> add_brackets()
        |> append_maps(acc, counter + 1)
      end) <>
      "\n#{add_identation(counter)}]"
  end

  defp process_val([[head | _t] = inner | _tail] = _val, counter) when is_binary(head) do
    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a list of binary values",
      counter: counter
    )

    "[" <>
      Enum.reduce(inner, "", fn m, acc ->
        orchestrate(m, counter)
        |> append(acc)
      end) <>
      "]"
  end

  defp process_val([head | tail] = _val, counter) when is_map(head) and tail == [] do
    counter = counter + 1

    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a map",
      head: head,
      counter: counter
    )

    "{\n#{add_identation(counter)}#{orchestrate(head, counter)}\n#{add_identation(counter)}}\n"
  end

  defp process_val([head | tail] = val, counter)
       when is_map(head) and tail != [] and length(tail) <= 2 do
    counter = counter + 1

    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a short list of maps",
      counter: counter
    )

    "{" <>
      Enum.reduce(val, "", fn m, acc -> orchestrate(m, 0) |> append(acc) end) <>
      "}"
  end

  defp process_val([head | tail] = val, counter)
       when is_map(head) and tail != [] and length(tail) >= 3 do
    Logger.debug(
      source: "[#{Path.basename(__ENV__.file)}]",
      message: "found a long list of maps",
      counter: counter
    )

    "{\n" <>
      Enum.reduce(val, "", fn m, acc -> orchestrate(m, counter + 1) |> append_maps(acc, 0) end) <>
      "\n#{add_identation(counter)}}"
  end

  defp process_val(val, _counter) when is_binary(val) do
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
  defp append(new, old) when new == "" and old == "" do
    ""
  end

  @spec append(String.t(), String.t()) :: String.t()
  defp append(new, old) do
    "#{old}, #{new}"
  end

  @spec append_maps(String.t(), String.t(), integer()) :: String.t()
  defp append_maps(new, old, counter) when old == "" do
    add_identation(counter) <> new
  end

  @spec append_maps(String.t(), String.t(), integer()) :: String.t()
  defp append_maps(new, old, counter) when new == "" do
    add_identation(counter) <> old
  end

  @spec append_maps(String.t(), String.t(), integer()) :: String.t()
  defp append_maps(new, old, _counter) when new == "" and old == "" do
    ""
  end

  @spec append_maps(String.t(), String.t(), integer()) :: String.t()
  defp append_maps(new, old, counter) do
    "#{old},\n#{add_identation(counter)}#{new}"
  end

  ## add brackets to separate when needed
  defp add_brackets(string) do
    "{#{string}}"
  end

  # Returns identation based on counter
  defp add_identation(counter) when counter > 0 do
    Stream.repeatedly(fn -> @tab end)
    |> Enum.take(counter)
    |> List.to_string()
  end

  defp add_identation(counter) when counter <= 0 do
    ""
  end
end
