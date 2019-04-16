defmodule AbtDidWorkshopWeb.AgreementController do
  use AbtDidWorkshopWeb, :controller

  def get(conn, %{"id" => id}) do
    text =
      :agreement
      |> AbtDidWorkshop.Util.config()
      |> Enum.filter(fn agr -> agr.meta.id == id end)
      |> List.first()
      |> Map.get(:content)

    text(conn, text)
  end
end
