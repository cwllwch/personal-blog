defmodule PortalWeb.LiveStuff.Prettify do
  require Logger
  alias JsonParser.JsonPrettifier, as: JP
  use PortalWeb, :live_view

  @moduledoc """
  This LiveView takes the json input, sends it for parsing as received, then returns the result in the second text area.
  """

  def mount(_params, _session, socket) do
    og_json = "{\\\"your-json\\\": \\\"here\\\"} 333"
    socket = assign(socket, :og_json, og_json)
    socket = assign(socket, :new_json, " ")
    {:ok, socket}
  end

  def handle_event("prettify", _values, socket) do
    og_json = socket.assigns.og_json
    new_json = JP.prettify(og_json)
    socket = assign(socket, :new_json, new_json)
    Logger.info(%{Original: og_json, New: new_json})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <h1>
      Make this JSON pretty!
      </h1>

      <hr>
      <form phx-submit="prettify" class="flex flex-row gap-4 items-center justify-center py-8 ">
        <textarea
        style="width:40%; height:36rem; color:black; font-size:14px"
          class= "flex-[2] text-sm bg-slate-800"
          wrap="hard"
        ><%= @og_json %></textarea>

        <.button
          type="submit">
             make pretty!
        </.button>

         <textarea
          style="width:40%; height:36rem;"
          class= "flex-1 text-sm"
          readonly
          rows="8"
          ><%= @new_json  %></textarea>
    </form>
    """
  end
end
