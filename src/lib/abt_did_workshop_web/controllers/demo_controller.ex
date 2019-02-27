defmodule AbtDidWorkshopWeb.DemoController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop
  alias AbtDidWorkshop.Repo
  alias AbtDidWorkshop.Demo

  def index(conn, _) do
    demos = Repo.all(Demo)
    render(conn, "index.html", demos: demos)
  end

  def show(conn, _) do
  end

  def new(conn, _) do
    changeset = Demo.changeset(%Demo{}, %{})
    assets = Demo.get_assets()
    render(conn, "new.html", changeset: changeset, asset_demos: assets)
  end

  def create(conn, %{"demo" => %{"behavior" => "issue_asset", "asset_content" => ""}}) do
    conn
    |> put_flash(:error, "Must fill in asset content to issue assets")
    |> redirect(to: Routes.demo_path(conn, :new))
  end

  def create(conn, %{"demo" => demo} = param) do
    asset_content =
      case demo["behavior"] do
        "issue_asset" -> demo["issue_asset"]
        _ -> ""
      end

    changeset =
      Demo.changeset(%Demo{}, %{
        name: demo["name"],
        description: demo["description"],
        behavior: demo["behavior"],
        asset_content: asset_content
      })

    case Repo.insert(changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Demo Created!")
        |> redirect(to: Routes.demo_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset, asset_demos: Demo.get_assets())
    end
  end

  def update(conn, _) do
  end

  def delete(conn, %{"id" => demo_id}) do
    Repo.get!(Demo, demo_id)
    |> Repo.delete!()

    conn
    |> put_flash(:info, "Demo Deleted")
    |> redirect(to: Routes.demo_path(conn, :index))
  end
end
