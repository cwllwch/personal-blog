defmodule PortalWeb.STController do
  use PortalWeb, :controller

  # initial load
  def speed_test(conn, %{}) do
    value = DateTime.now!("Etc/UTC") |> DateTime.to_unix(:millisecond)
    
    conn
    |> assign(:page, "speed test")
    |> assign(:value, value)
    |> assign(:diff, "loading...")
    |> render(:speed_test)
  end

  # load with params
  def ping(conn, %{"value" => prev_value}) do
    now = DateTime.now!("Etc/UTC") |> DateTime.to_unix(:millisecond)

    # calculate the diff between now and then + 3s offset (a kind of rate limiter to not make these requests ddos myself) and divided by the two legs of the trip
    diff = now - (String.to_integer(prev_value) + 3_000) |> Kernel.div(2)
    conn
    |> assign(:value, now)
    |> assign(:diff, diff)
    |> render(:speed_test)
  end
end
