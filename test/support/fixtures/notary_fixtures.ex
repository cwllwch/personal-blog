defmodule Portal.NotaryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Portal.Notary` context.
  """

  @doc """
  Generate a unique note note_id.
  """
  def unique_note_note_id do
    raise "implement the logic to generate a unique note note_id"
  end

  @doc """
  Generate a note.
  """
  def note_fixture(attrs \\ %{}) do
    {:ok, note} =
      attrs
      |> Enum.into(%{
        due_date: ~D[2026-02-24],
        note: "some note",
        note_id: unique_note_note_id(),
        title: "some title"
      })
      |> Portal.Notary.create_note()

    note
  end
end
