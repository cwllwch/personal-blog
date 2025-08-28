defmodule PortalWeb.PageController do
  use PortalWeb, :controller

  def home(conn, _params) do
    conn = assign(conn, :page, "homepage")
    render(conn, :home)
  end

  def contact(conn, _params) do
    conn = assign(conn, :page, "contact")
    render(conn, :contact)
  end

  def about(conn, _params) do
    conn = assign(conn, :page, "about")
    render(conn, :about)
  end

  def prettify(conn, _params) do
    conn = assign(conn, :prettify, "prettify my json!") 
    render(conn, :prettify)
  end
end
