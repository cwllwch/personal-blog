defmodule PortalWeb.Components.CustomComponents do
  use Phoenix.Component

  @moduledoc """
  Components custom made for this project. 
  """

  @doc """
  Renders a textbox with the provided info. It 
  conditionally changes colors depending on what 
  variable is passed to it
  """
  attr :message, :string, required: true
  attr :level, :atom, required: true
  slot :inner_block
  def display_text(%{level: :normal} = assigns) do
    ~H"""
    <div class="flex h-[36rem] aspect-[5/4] p-3
                bg-white rounded-xl text-gray-500">
        result will show up here
    </div>
    """
  end

  def display_text(%{level: :valid} = assigns) do
    ~H"""
    <div class="flex h-[36rem] aspect-[5/4] p-3 bg-white rounded-xl 
                shadow-lg shadow-lime-400/30 ring ring-lime-400/40
                whitespace-pre-wrap">{Jason.Formatter.pretty_print(@message)}
    </div>
    """
  end

  
  def display_text(%{level: :parsed} = assigns) do
    ~H"""
    <div class="flex h-[36rem] aspect-[5/4] p-3 bg-white rounded-xl 
                shadow-lg shadow-amber-400/30 ring ring-amber-400/40
                whitespace-pre-wrap">{Jason.Formatter.pretty_print(@message)}
    </div>
    """
  end

  def display_text(%{level: :error} = assigns) do
    ~H"""
    <div class="flex h-[36rem] aspect-[5/4] p-3 bg-white rounded-xl 
                shadow-lg shadow-red-400/30 ring ring-red-400/40
                whitespace-pre-wrap">
      {@message}
    </div>
    """
  end 
end
