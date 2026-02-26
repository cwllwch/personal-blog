defmodule PortalWeb.UserRegistrationController do
  use PortalWeb, :controller

  alias Portal.Noters
  alias Portal.Noters.User
  alias PortalWeb.UserAuth

  def new(conn, _params) do
    changeset = Noters.change_user_registration(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Noters.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Noters.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
