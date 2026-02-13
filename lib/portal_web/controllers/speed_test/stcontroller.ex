defmodule PortalWeb.STController do
  use PortalWeb, :controller

  def speed_test(conn, %{"value" => value}) do
    conn
    |> assign(:page, "speed test!")
    |> assign(:value, value)
    |> render(:speed_test)
  end

  def speed_test(conn, _params) do
    conn
    |> assign(:page, "speed test!")
    |> assign(:value, 0)
    |> render(:speed_test)
  end

  def htmx_hello(conn, %{"value" => value}) do
    conn 
    |> assign(:value, value)
    |> render(:htmx_hello)
  end

  def new_page(conn, _params) do
    conn
    |> render(:new_page)
  end
end
