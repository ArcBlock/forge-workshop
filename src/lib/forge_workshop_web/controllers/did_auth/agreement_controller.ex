defmodule ForgeWorkshopWeb.AgreementController do
  use ForgeWorkshopWeb, :controller

  def get(conn, %{"id" => id}) do
    text =
      :agreement
      |> ForgeWorkshop.Util.config()
      |> Enum.filter(fn agr -> agr.meta.id == id end)
      |> List.first()
      |> Map.get(:content)

    text(conn, text)
  end
end
