defmodule PortalWeb.Whoami.AskForUsername do
  use PortalWeb, :controller

  @moduledoc """
  A plug/controller that simply asks the user to give a username. Doesn't have to be 
  unique or anything. It's just a way for the server to identify players.
  """

  def init(opts), do: opts

  def call(conn, :save_redirect) do
    Plug.Conn.put_session(conn, :return_to, ~p{/whoami?#{conn.params}})
  end

  def call(conn, :set_username) do
    %{"user" => user} = conn.params

    return_to = get_session(conn, :return_to)

    if return_to == nil do
      conn
      |> put_resp_cookie("user", user, sign: true)
      |> redirect(to: ~p"/whoami#body")
    else
      conn
      |> put_resp_cookie("user", user, sign: true)
      |> delete_session(:return_to)
      |> redirect(to: return_to <> "#body")
    end
  end

  def call(conn, :ask_for_username) do
    conn = Plug.Conn.fetch_cookies(conn, signed: ~w(user))

    case evaluate_username(conn.cookies) do
      {:ok, username} ->
        assign(conn, :user, username)
        |> Plug.Conn.put_session(:user, username)

      {:error, nil} ->
        redirect(conn, to: ~p"/whoami/set-user#body")
        |> halt()
    end
  end

  def call(conn, :remove_username) do
    Plug.Conn.delete_resp_cookie(conn, "user", signed: ~w(user))
    |> put_flash(:info, "Removed your previous username")
    |> redirect(to: ~p"/whoami#body")
    |> halt()
  end

  defp evaluate_username(%{"user" => val}) do
    {:ok, val}
  end

  defp evaluate_username(_cookies) do
    {:error, nil}
  end
end
