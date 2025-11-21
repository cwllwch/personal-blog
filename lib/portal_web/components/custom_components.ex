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
  attr :name, :string, required: true
  slot :inner_block

  def display_text(%{level: :normal} = assigns) do
    ~H"""
    <textarea name={@name} 
        class="bg-white rounded-xl text-gray-500 h-full w-full"
              >result will show up here
    </textarea>
    """
  end

  def display_text(%{level: :valid} = assigns) do
    ~H"""
    <div class="p-3 bg-white rounded-xl h-full w-full
                shadow-xl shadow-lime-400/30 ring ring-lime-400/60
                whitespace-pre-wrap overflow-scroll" 
      >{Jason.Formatter.pretty_print(elem(@message, 1))}
    </div>
    """
  end

  def display_text(%{level: :parsed} = assigns) do
    ~H"""
    <div class="p-3 bg-white rounded-xl h-full w-full
                shadow-xl shadow-[#4287f5] ring ring-[#4287f5]
                whitespace-pre-wrap overflow-scroll"
      >{Jason.Formatter.pretty_print(@message)} 
      </div>
    """
  end

  def display_text(%{level: :error} = assigns) do
    ~H"""
    <div class="p-3 bg-white rounded-xl h-full w-full
                shadow-xl shadow-red-400/30 ring ring-red-400/60
                whitespace-pre-wrap overflow-scroll"
        >is this really a json? check if you have an extra bracket around, that really confuses me
    </div>
    """
  end
end
