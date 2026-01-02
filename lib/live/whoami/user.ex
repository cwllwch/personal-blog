defmodule PortalWeb.LiveStuff.Whoami.SetUser do
  use PortalWeb, :live_view

  @moduledoc """
  Creates a signed and encrypted username cookie
  why is it signed and encrypted? just so that 
  whatever the player chooses is forever with them
  """

  def mount(_params, _session, socket) do
    new_socket =
      assign(socket,
        page_title: "whoami - enter username"
      )

    {:ok, new_socket}
  end

  def render(assigns) do
    ~H"""
    <div class="field">
      <div>You will need to name yourself for this.</div>
      <form phx-submit="set_username" class="grid grid-rows-2 grid-cols-1" style="gap: 2vi;">
        <input type="text" name="user" class="rounded-xl bg-zinc-800 text-white" />
        <.button type="submit">Choose username</.button>
      </form>
    </div>
    """
  end

  def handle_event("set_username", %{"user" => user}, socket) do
    {:noreply, redirect(socket, to: ~p"/set-user?user=#{user}")}
  end
end
