defmodule Portal.Notary.Note do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notes" do
    field :title, :string
    field :note, :string
    field :due_date, :date
    field :note_id, Ecto.UUID

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:note, :title, :due_date, :note_id])
    |> validate_required([:note, :title, :due_date, :note_id])
    |> unique_constraint(:note_id)
  end
end
