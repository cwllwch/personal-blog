defmodule PortalWeb.LiveStuff.Prettify do
  use PortalWeb, :live_view

  def mount(_params, _session, socket) do
    og_json = "{\\\"your-json\\\": \\\"here\\\"}"
    socket = assign(socket, :og_json, og_json)
    {:ok, socket}
  end

  def handle_event("prettify", _values, socket) do
    IO.inspect("prettifying")
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <h1>
      Make this JSON pretty!
      </h1>
  
      <hr>
      <form phx-submit="prettify">
      <div class="flex content-start items-center justify-content gap-8" id="">
        <div class="flex-initial flex-1">
          <textarea rows="8" class="py-4 px-8 mt-8 rounded bg-slate-400 boder-emerald-400 "> <%= @og_json %> </textarea>
        </div>


      <div class="flex-initial flex-1"> 
        <.button phx-click="prettify">
          make it nice <br>
            >> >> >>
        </.button>
      </div>

      <div class="flex-initial flex-1">
        <textarea rows="8" class="py-4 px-8 mt-8 rounded bg-slate-400">
        </textarea>
      </div>
      </div>
    </form>
    """
  end
end

