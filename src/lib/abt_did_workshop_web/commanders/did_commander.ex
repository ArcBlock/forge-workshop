defmodule AbtDidWorkshopWeb.DidCommander do
  @moduledoc false

  use Drab.Commander

  alias AbtDidWorkshop.UserDb

  onload(:page_loaded)

  def page_loaded(socket) do
    UserDb.add_socket(socket)
  end
end
