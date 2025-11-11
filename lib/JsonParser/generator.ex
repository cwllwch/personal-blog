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

    IO.inspect("{ " <> orchestrate(ast) <> " }")

    ast

  end

  defp orchestrate(ast) do
    [f_key | remaining_keys] = get_key(ast)
    f_val = get_val(ast, f_key)

    Logger.info([
      source: "[" <> Path.basename(__ENV__.file) <> "]",
      function: "orchestrate/1",
      remaining_keys: length(remaining_keys),
      f_key: f_key,
      f_val: f_val
    ], 
    ansi_color: :light_magenta)

    orchestrate(ast, {f_key, f_val}, remaining_keys)
  end

  defp orchestrate(ast, {key,  val}, remaining_keys) when remaining_keys != [] and is_list(val) do
    
  end

  defp orchestrate(ast, {key, val}, remaining_keys) when remaining_keys == [] and is_list(val) do
    key = evaluate_nested_obj(val)
  end

  defp orchestrate(ast, {key, val}, remaining_keys) when remaining_keys == [] and is_binary(val) do
    "{#{key}: #{val}}"
  end

  defp evaluate_nested_obj(val) when length(val) == 1 do
    List.first(val)
    |> get_key()
  end

  defp evaluate_nested_obj([first | tail] = val) when length(val) >= 2 do
    value = orchestrate(first)
    evaluate_nested_obj(tail, value)
  end

  defp evaluate_nested_obj(val, acc) when length(val) == 1 do
    key = List.first(val)
    new_val = get_val(val, [key])

    "#{acc}, \n{#{key}: #{new_val}}"
  end

  ## Key logic
  defp get_key(map) do
    Map.keys(map)
  end

  ## Value logic
  defp get_val(map, _key) when is_list(map) do
    orchestrate(List.first(map))
  end

  defp get_val(map, key) when is_map(map) do
    get_in(map, [key])
  end
end
