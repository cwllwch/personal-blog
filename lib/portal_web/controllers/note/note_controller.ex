defmodule PortalWeb.NoteController do
  use PortalWeb, :controller

  alias Portal.Notary
  alias Portal.Notary.Note

  def index(conn, _params) do
    notes = Notary.list_notes()
    render(conn, :index, notes: notes)
  end

  def new(conn, _params) do
    changeset = Notary.change_note(%Note{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"note" => note_params}) do
    case Notary.create_note(note_params) do
      {:ok, note} ->
        conn
        |> put_flash(:info, "Note created successfully.")
        |> redirect(to: ~p"/notes/#{note}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    note = Notary.get_note!(id)
    render(conn, :show, note: note)
  end

  def edit(conn, %{"id" => id}) do
    note = Notary.get_note!(id)
    changeset = Notary.change_note(note)
    render(conn, :edit, note: note, changeset: changeset)
  end

  def update(conn, %{"id" => id, "note" => note_params}) do
    note = Notary.get_note!(id)

    case Notary.update_note(note, note_params) do
      {:ok, note} ->
        conn
        |> put_flash(:info, "Note updated successfully.")
        |> redirect(to: ~p"/notes/#{note}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, note: note, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    note = Notary.get_note!(id)
    {:ok, _note} = Notary.delete_note(note)

    conn
    |> put_flash(:info, "Note deleted successfully.")
    |> redirect(to: ~p"/notes")
  end
end
