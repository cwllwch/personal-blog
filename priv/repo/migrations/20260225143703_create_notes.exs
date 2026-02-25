defmodule Portal.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :note, :text
      add :title, :text
      add :due_date, :date
      add :note_id, :uuid

      timestamps(type: :utc_datetime)
    end

    create unique_index(:notes, [:note_id])
  end
end
