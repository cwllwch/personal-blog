defmodule PortalWeb.Router do
  use PortalWeb, :router

  import PortalWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
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
    pipe_through :htmx

    get "/ping", PortalWeb.STController, :ping
  end

  scope "/", PortalWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/contact", PageController, :contact
    get "/about", PageController, :about
    get "/set-user", Whoami.AskForUsername, :set_username
    get "/speed-test", STController, :speed_test
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

  ## Authentication routes

  scope "/", PortalWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", PortalWeb do
    pipe_through [:browser, :require_authenticated_user]

    resources "/notes", NoteController
    get "/notary", NoteController, :index
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", PortalWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
