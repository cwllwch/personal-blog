defmodule PortalWeb.LiveStuff.Prettify do
  require Logger
  alias JsonParser.Main, as: JP
  alias PortalWeb.Components.CustomComponents
  use PortalWeb, :live_view

  @moduledoc """
  This LiveView takes the json input, sends it for parsing as received, then returns the result in the second text area.
  """

  # Setting the initial state of the page on load
  def mount(_params, _session, socket) do
    new_socket =
      assign(socket,
        page: "json prettifier",
        string: "",
        level: :normal,
        error: nil
      )

    {:ok, new_socket}
  end

  def handle_event("prettify", %{"_action" => "clean"}, socket) do
    socket =
      assign(socket, :string, "")
      |> assign(:level, :normal)

    {:noreply, socket}
  end

  def handle_event("prettify", %{"_action" => "send", "og_json" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("prettify", %{"_action" => "send", "og_json" => og_json}, socket) do
    case JP.prettify(og_json) do
      {:ok, new_json} ->
        socket =
          assign(socket, :string, new_json)
          |> assign(:level, :valid)

        {:noreply, socket}

      {:parsed, parsed} ->
        socket =
          assign(socket, :string, parsed)
          |> assign(:level, :parsed)

        {:noreply, socket}

      {:error, reason} ->
        Logger.info(
          message: "error from json parser",
          error: reason
        )

        socket =
          assign(socket, :level, :error)

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <h1>
      Make this JSON pretty
    </h1>
    <p class="about">
      This is aimed at making slightly off jason text into something readable. The
      original problem that made me want to do this was encountering json logs that
      had been treated as elixir lists in formatting, leading to them becoming rather
      unpleasant to read.

      The result area will glow in <span style="color: #10b981; font-weight: 600">green</span>
      if your text is already valid json, <span style="color: #4287f5; font-weight: 600">blue</span>
      if parsing was needed, or <span style="color: #f87171; font-weight: 600">red</span>
      if an error was
      encountered and the whole thing failed.
    </p>

    <hr class="border-t border-emerald-400 m-5" />
    <form phx-submit="prettify">
      <div class={if @string == "", do: "p_grid_q", else: "p_grid_r"}>
        <textarea
          class={if @string == "", do: "expand", else: "fold"}
          name="og_json"
          placeholder="paste the json!"
          wrap="soft"
        ></textarea>

        <div class="btn-container">
          <.button type="submit" name="_action" value="send">
            make pretty
          </.button>

          <.button type="submit" name="_action" value="clean">
            clear
          </.button>
        </div>

        <div class={if @string == "", do: "fold", else: "expand"}>
          <CustomComponents.display_text message={@string} level={@level} name="result">
          </CustomComponents.display_text>
        </div>
      </div>
    </form>
    """
  end
end
