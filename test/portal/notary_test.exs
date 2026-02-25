defmodule Portal.NotaryTest do
  use Portal.DataCase

  alias Portal.Notary

  describe "notes" do
    alias Portal.Notary.Note

    import Portal.NotaryFixtures

    @invalid_attrs %{title: nil, note: nil, due_date: nil, note_id: nil}

    test "list_notes/0 returns all notes" do
      note = note_fixture()
      assert Notary.list_notes() == [note]
    end

    test "get_note!/1 returns the note with given id" do
      note = note_fixture()
      assert Notary.get_note!(note.id) == note
    end

    test "create_note/1 with valid data creates a note" do
      valid_attrs = %{title: "some title", note: "some note", due_date: ~D[2026-02-24], note_id: "7488a646-e31f-11e4-aace-600308960662"}

      assert {:ok, %Note{} = note} = Notary.create_note(valid_attrs)
      assert note.title == "some title"
      assert note.note == "some note"
      assert note.due_date == ~D[2026-02-24]
      assert note.note_id == "7488a646-e31f-11e4-aace-600308960662"
    end

    test "create_note/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Notary.create_note(@invalid_attrs)
    end

    test "update_note/2 with valid data updates the note" do
      note = note_fixture()
      update_attrs = %{title: "some updated title", note: "some updated note", due_date: ~D[2026-02-25], note_id: "7488a646-e31f-11e4-aace-600308960668"}

      assert {:ok, %Note{} = note} = Notary.update_note(note, update_attrs)
      assert note.title == "some updated title"
      assert note.note == "some updated note"
      assert note.due_date == ~D[2026-02-25]
      assert note.note_id == "7488a646-e31f-11e4-aace-600308960668"
    end

    test "update_note/2 with invalid data returns error changeset" do
      note = note_fixture()
      assert {:error, %Ecto.Changeset{}} = Notary.update_note(note, @invalid_attrs)
      assert note == Notary.get_note!(note.id)
    end

    test "delete_note/1 deletes the note" do
      note = note_fixture()
      assert {:ok, %Note{}} = Notary.delete_note(note)
      assert_raise Ecto.NoResultsError, fn -> Notary.get_note!(note.id) end
    end

    test "change_note/1 returns a note changeset" do
      note = note_fixture()
      assert %Ecto.Changeset{} = Notary.change_note(note)
    end
  end
end
