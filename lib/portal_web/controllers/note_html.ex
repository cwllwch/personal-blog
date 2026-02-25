defmodule PortalWeb.NoteHTML do
  use PortalWeb, :html

  embed_templates "note_html/*"

  @doc """
  Renders a note form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def note_form(assigns)
end
