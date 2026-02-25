defmodule PortalWeb.NoteControllerTest do
  use PortalWeb.ConnCase

  import Portal.NotaryFixtures

  @create_attrs %{title: "some title", note: "some note", due_date: ~D[2026-02-24], note_id: "7488a646-e31f-11e4-aace-600308960662"}
  @update_attrs %{title: "some updated title", note: "some updated note", due_date: ~D[2026-02-25], note_id: "7488a646-e31f-11e4-aace-600308960668"}
  @invalid_attrs %{title: nil, note: nil, due_date: nil, note_id: nil}

  describe "index" do
    test "lists all notes", %{conn: conn} do
      conn = get(conn, ~p"/notes")
      assert html_response(conn, 200) =~ "Listing Notes"
    end
  end

  describe "new note" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/notes/new")
      assert html_response(conn, 200) =~ "New Note"
    end
  end

  describe "create note" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/notes", note: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/notes/#{id}"

      conn = get(conn, ~p"/notes/#{id}")
      assert html_response(conn, 200) =~ "Note #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/notes", note: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Note"
    end
  end

  describe "edit note" do
    setup [:create_note]

    test "renders form for editing chosen note", %{conn: conn, note: note} do
      conn = get(conn, ~p"/notes/#{note}/edit")
      assert html_response(conn, 200) =~ "Edit Note"
    end
  end

  describe "update note" do
    setup [:create_note]

    test "redirects when data is valid", %{conn: conn, note: note} do
      conn = put(conn, ~p"/notes/#{note}", note: @update_attrs)
      assert redirected_to(conn) == ~p"/notes/#{note}"

      conn = get(conn, ~p"/notes/#{note}")
      assert html_response(conn, 200) =~ "some updated title"
    end

    test "renders errors when data is invalid", %{conn: conn, note: note} do
      conn = put(conn, ~p"/notes/#{note}", note: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Note"
    end
  end

  describe "delete note" do
    setup [:create_note]

    test "deletes chosen note", %{conn: conn, note: note} do
      conn = delete(conn, ~p"/notes/#{note}")
      assert redirected_to(conn) == ~p"/notes"

      assert_error_sent 404, fn ->
        get(conn, ~p"/notes/#{note}")
      end
    end
  end

  defp create_note(_) do
    note = note_fixture()
    %{note: note}
  end
end
