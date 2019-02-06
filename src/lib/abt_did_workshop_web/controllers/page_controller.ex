defmodule AbtDidWorkshopWeb.PageController do
  use AbtDidWorkshopWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
