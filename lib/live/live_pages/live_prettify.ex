defmodule PortalWeb.LiveStuff.Prettify do
  require Logger
  alias JsonParser.Main, as: JP
  use PortalWeb, :live_view

  @moduledoc """
  This LiveView takes the json input, sends it for parsing as received, then returns the result in the second text area.
  """

  def mount(_params, _session, socket) do
    socket = assign(socket, :new_json, " ")
    new_socket = assign(socket, :page_title, "prettifier")
    {:ok, new_socket}
  end

  def handle_event("prettify", %{"_action" => "clean"}, socket) do
    socket = assign(socket, :new_json, "")
    |> assign(:og_json, "")
    {:noreply, socket}
  end

  def handle_event("prettify", %{"_action" => "send", "og_json" => ""}, socket) do
      {:noreply, socket}
  end

  def handle_event("prettify", %{"_action" => "send", "og_json" => og_json}, socket) do
    
    new_json = JP.prettify(og_json)
    socket = assign(socket, :new_json, new_json)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <h1>
      Make this JSON pretty!
      </h1>

      <hr class="emerald-400">
      <form phx-submit="prettify" class="flex flex-row gap-4 items-center justify-center py-8 ">
        <textarea
          style="width:40%; height:36rem; color:black; font-size:14px"
          class= "flex-[2] text-sm bg-slate-800"
          name="og_json"
          placeholder="paste the json!"
          wrap="soft"
        ></textarea>

        <div class="flex-2 flex flex-col gap-4">
        <.button
          type="submit"
          name="_action"
          value="send"
          >
             make pretty!
        </.button>

        <.button
        type="submit"
        name="_action"
        value="clean">
        clear
        </.button>
        </div>

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
