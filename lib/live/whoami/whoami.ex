defmodule PortalWeb.LiveStuff.WhoAmI do
  require Logger

  use PortalWeb, :live_view
  
  import Live.Whoami.Components

  alias Phoenix.Presence
  alias PortalWeb.Presence
  alias Whoami.Main, as: Lobby
  alias Whoami.Player

  @moduledoc """
  Orchestrates the game featured in Inglorious Bastards where
  everyone writes a famous person on a card then gets assigned 
  someone else's card. 
  Every time a new liveview with a cookie shows up to a lobby, a
  user is created in the session, and then stored in the socket. 
  This is because sessions store usernames and each socket a user, 
  and then sockets will insert users into the lobby.

  also some nomeclature weirdness: i decided to separate user and 
  player - user is just username in session, and player is the 
  entity associated with the lobby.
  """

  # This should match if there is no user set for this lobby. 
  def mount(%{"lobby" => lobby}, session, %{user: nil} = socket) do
    Logger.info([
      message: "making a new player for this user in current lobby", 
      user: session["user"], 
      lobby: lobby
    ])

    topic = "lobby:#{lobby}"
    new_socket =
      assign(socket,
        page_title: "who am i?",
        player: create_player(session["user"])
      )

    if connected?(new_socket) do
      {:ok, _} = Presence.track(
        self(), 
        topic, 
        new_socket.assigns.player.id, 
        %{
          user: new_socket.assigns.player, 
          connected: true,
          timestamp: inspect(System.system_time(:second))
        }
      )
      IO.inspect("connected to #{topic}")
    end

    {:ok, new_socket}
  end
  
  # This clause matches an existing user in a lobby
  def mount(%{"lobby" => lobby} = _params, session, socket) do
    Logger.info([
      message: "trying to find existing player in lobby", 
      user: session["user"], 
      lobby: lobby
    ])

    case find_player(session["user"], lobby) do
      {:ok, nil} -> 
        Logger.info([message: "adding new player to lobby", user: session["user"]])
        new_socket = assign(socket,
          page_title: "who am i?",
          player: create_player(session["user"])
          )
        |> put_flash(:info, "You are now in a lobby!")
        {:ok, new_socket}
    
      {:ok, user} -> 
        Logger.debug("found player #{inspect(session["user"])} in lobby #{inspect(lobby)}")
        new_socket = assign(socket,
          page_title: "who am i?",
          player: user
          )
        {:ok, new_socket}
      {:error, message} -> 
        new_socket = assign(socket,
          page_title: "who am i?",
          player: create_player(session["user"])
        )
        |> put_flash(:error, message)
        {:ok, push_navigate(new_socket, to: ~p{/whoami})}
    end
  end

  # This matches for new lobby sessions, with a user in session
  # but not in the socket.
  def mount(params, session, socket) when params == %{} do
    Logger.info([
      message: "no player nor lobby, prompting creation of both",
      user: session["user"]
    ])

    new_socket =
      assign(socket,
        page_title: "who am i?",
        player: create_player(session["user"])
      )

    {:ok, new_socket}
  end



  def handle_params(%{"lobby" => lobby}, _session, socket) when socket.assigns.player != nil do
    topic = "lobby:#{lobby}"

    if connected?(socket) do
      {:ok, _} = Presence.track(
        self(), 
        topic, 
        socket.assigns.player.id, 
        %{
          user: socket.assigns.player, 
          connected: true,
          timestamp: inspect(System.system_time(:second))
        }
      )
      IO.inspect("connected to #{topic}")
    end
  
    presences = Presence.list("lobby:#{lobby}")
    |> flatten_presences(socket.assigns.player)
    |> IO.inspect()
    
    new_socket = assign(socket,
      lobby_id: lobby,
      loading: false, 
      in_lobby: true,
      players_in_lobby: presences
    )
    {:noreply, new_socket}
  end

  def handle_params(_params, _session, socket) do
    new_socket =
      assign(socket,
        loading: false,
        in_lobby: false,
        lobby_id: nil,
        players_in_lobby: [],
        link: nil
      )

    {:noreply, new_socket}
  end

  def render(assigns) do
    ~H"""
    <p></p>
    <div class="field">
      <%= cond do %>
        <% @loading == true -> %>
          <div class="justify-self-center justify-center"> 
            <.icon name="hero-arrow-path" class="animate-spin text-white" /> loading...
          </div>

        <% @in_lobby == false and @loading == false -> %>
          <.new_lobby
            question={"How many are playing, " <> @player.name <> "?"} 
            button="create the lobby"
          />

        <% @in_lobby == true and @loading == false -> %>
          <.waiting_room lobby_id={@lobby_id} players={@players_in_lobby} />

      <% end %>
          <%= inspect(@players_in_lobby, pretty: true) %>
    </div>
    """
  end

  def handle_event("request_lobby", %{"player_count" => player_count}, socket) do
    send(self(), {:create_lobby, String.to_integer(player_count)})
    new_socket = assign(socket, :loading, true)
    {:noreply, new_socket}
  end

  def handle_event("fetch_players", _params, socket) do
    send(self(), {:fetch_players, socket.assigns.lobby_id})
    new_socket = assign(socket, :loading, true)
    {:noreply, new_socket}
  end

  def handle_info({:create_lobby, player_count}, socket) do
    {:ok, _pid, lobby_id} = Lobby.create_lobby(player_count, socket.assigns.player)

    link = ~p{/whoami?#{%{lobby: lobby_id}}}

    new_socket =
      assign(socket, :loading, false)
      |> assign(:lobby_id, lobby_id)
      |> assign(:link, link)
      |> assign(:in_lobby, true)

    {:noreply, push_patch(new_socket, to: link)}
  end

  def handle_info({:fetch_players, l_id}, socket) do
    players =
      Lobby.fetch_players(l_id)
      |> Enum.filter(fn item -> item.name == socket.assigns.player end)
      |> Enum.reduce([], fn p, acc -> acc ++ [Map.get(p, :name)] end)

    {:noreply, assign(socket, players_in_lobby: players, loading: false)}
  end

  defp create_player(username) do
    %Player{
      name: username,
      id: Lobby.generate_id(),
      points: 0,
      wins: 0
    }
  end

  def find_player(username, lobby) do
    case Lobby.fetch_players(lobby) do
      {:ok, users} -> {:ok, Enum.filter(users, fn user -> user.name == username end) |> List.first()}
      {:error, message} -> 
        Logger.info([message: "tried to find a lobby that doesn't exist", user: username])
        {:error, message}
    end
  end

  defp flatten_presences(presences, self_id) do
    Enum.reject(presences, fn {k, _v} -> k == self_id end)
    |> Enum.reduce([], 
      fn {_key, val}, acc -> 
        acc ++ [List.first(val.metas)] 
      end)
  end
end
