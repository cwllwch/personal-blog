defmodule PortalWeb.LiveStuff.Prettify do
  require Logger
  use JsonParser.JsonPrettifier, alias: JP
  use PortalWeb, :live_view

  @moduledoc """
  This LiveView takes the json input, sends it for parsing as received, then returns the result in the second text area.
  """

  def mount(_params, _session, socket) do
    og_json = "{\\\"your-json\\\": \\\"here\\\"}"
    socket = assign(socket, :og_json, og_json)
    socket = assign(socket, :new_json, " ")
    {:ok, socket}
  end

  def handle_event("prettify", _values, socket) do
    Logger.info("Got a JSON prettify request")
    og_json = socket.assigns.og_json 
    new_json = 
    socket = assign(socket, :new_json, new_json)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <h1>
      Make this JSON pretty!
      </h1>
  
      <hr>
      <form phx-submit="prettify">
      <div class="flex content-start items-center justify-content gap-8">
        <div class="flex-initial flex-1">
          <textarea 
          rows="8"
          class="mt-8 rounded bg-slate-400 boder-emerald-400" 
          value="user_input"
          wrap="soft"
          ><%= @og_json %></textarea>

        </div>


      <div class="flex-initial flex-2"> 
        <.button phx-click="prettify" type="submit">
          <div class="hidden md:block">
            make it nice <br>
              >> >> >> </div> 
            <div class="sm:block md:hidden">
              >> 
            </div>
        </.button>
     </div>

      <div class="flex-3">
        <textarea 
        readonly
        rows="8" 
        class="py-4 px-8 mt-8 rounded bg-slate-400" 
        ><%= @new_json  %></textarea>
      </div>
      </div>
    </form>
    """
  end
end 

