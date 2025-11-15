defmodule PortalWeb.PageControllerTest do
  use PortalWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "homepage"
  end
end
