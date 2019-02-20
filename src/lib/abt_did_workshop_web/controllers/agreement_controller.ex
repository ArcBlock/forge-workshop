defmodule AbtDidWorkshopWeb.AgreementController do
  use AbtDidWorkshopWeb, :controller

  def get(conn, %{"id" => id}) do
    text =
      :abt_did_workshop
      |> Application.get_env(:agreement, [])
      |> Enum.filter(fn agr -> agr.meta.id == id end)
      |> List.first()
      |> Map.get(:content)

    text(conn, text)
  end
end
