defmodule PortalWeb.Components.CustomComponents do
  use Phoenix.Component

  @moduledoc """
  Components custom made for the parser page. 
  """

  @doc """
  Renders a textbox with the provided info. It 
  conditionally changes colors depending on what 
  variable is passed to it
  """
  attr :message, :string, required: true
  attr :level, :atom, required: true
  attr :name, :string, required: true
  slot :inner_block

  def display_text(%{level: :normal} = assigns) do
    ~H"""
    <textarea name={@name} class="vanilla-textbox">result will show up here</textarea>
    """
  end

  def display_text(%{level: :valid} = assigns) do
    ~H"""
    <div class="valid-textbox">{Jason.Formatter.pretty_print(elem(@message, 1))}</div>
    """
  end

  def display_text(%{level: :parsed} = assigns) do
    ~H"""
    <div class="parsed-textbox">{@message}</div>
    """
  end

  def display_text(%{level: :error} = assigns) do
    ~H"""
    <div class="error-textbox">
      is this really a json? check if you have an extra bracket floating around
    </div>
    """
  end
end
