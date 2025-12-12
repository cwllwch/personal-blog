defmodule PortalWeb.Router do
  use PortalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PortalWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/contact", PageController, :contact
    get "/about", PageController, :about
    live "/prettify-my-json", LiveStuff.Prettify
    live "/whoami", LiveStuff.WhoAmI
  end

  if Application.compile_env(:portal, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PortalWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
