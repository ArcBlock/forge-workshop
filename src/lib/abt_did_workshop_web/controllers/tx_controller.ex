defmodule AbtDidWorkshopWeb.TxController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop
  alias AbtDidWorkshop.{Repo, Tx, Tables.TxTable, Tables.DemoTable}

  def index(conn, %{"demo" => demo_id}) do
    demo = DemoTable.get(demo_id)
    txs = TxTable.get_all(demo_id)
    render(conn, "index.html", txs: txs, demo: demo)
  end

  def new(conn, %{"demo" => demo_id}) do
    changeset = Tx.changeset(%Tx{}, %{})
    offers = demo_id |> String.to_integer() |> TxTable.get_offer_txs()
    render(conn, "new.html", changeset: changeset, offers: offers)
  end

  def create(conn, %{"demo" => %{"behavior" => "issue_asset", "asset_content" => ""}}) do
    conn
    |> put_flash(:error, "Must fill in asset content to issue assets")
    |> redirect(to: Routes.tx_path(conn, :new))
  end

  def create(conn, %{"demo" => demo}) do
    asset_content =
      case demo["behavior"] do
        "issue_asset" -> demo["issue_asset"]
        _ -> ""
      end

    changeset =
      Tx.changeset(%Tx{}, %{
        name: demo["name"],
        description: demo["description"],
        behavior: demo["behavior"],
        asset_content: asset_content
      })

    case Repo.insert(changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Tx Created!")
        |> redirect(to: Routes.tx_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset, offers: [])
    end
  end

  def update(conn, _) do
  end

  def delete(conn, %{"id" => demo_id}) do
    Repo.get!(Tx, demo_id)
    |> Repo.delete!()

    conn
    |> put_flash(:info, "Tx Deleted")
    |> redirect(to: Routes.tx_path(conn, :index))
  end
end
