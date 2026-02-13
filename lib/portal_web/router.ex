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

  pipeline :htmx do
    plug :accepts, ["html"]
    plug :put_layout, false
    plug :put_secure_browser_headers
  end

  pipeline :with_username do
    plug PortalWeb.Whoami.AskForUsername, :save_redirect
    plug PortalWeb.Whoami.AskForUsername, :ask_for_username
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PortalWeb do
    pipe_through [:browser, :with_username]

    get "/remove-username", Whoami.AskForUsername, :remove_username
    live "/whoami", LiveStuff.Whoami
  end

  scope "/speed-test" do
    pipe_through [:htmx]
    
    get "/hello-htmx", PortalWeb.STController, :htmx_hello
  end

  scope "/", PortalWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/contact", PageController, :contact
    get "/about", PageController, :about
    get "/set-user", Whoami.AskForUsername, :set_username
    get "/speed-test",  STController, :speed_test
    live "/prettify-my-json", LiveStuff.Prettify
    live "/whoami/set-user", LiveStuff.Whoami.SetUser
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
