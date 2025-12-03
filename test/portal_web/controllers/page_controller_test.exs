defmodule PortalWeb.PageControllerTest do
  use PortalWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "homepage"
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, ~p"/about") 
    assert html_response(conn, 200) =~ "about this site"
  end

  test "GET /contact", %{conn: conn} do
    conn = get(conn, ~p"/contact") 
    assert html_response(conn, 200) =~ "you can reach out to me via the following:"
  end
end
