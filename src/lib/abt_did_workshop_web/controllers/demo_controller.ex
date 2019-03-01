defmodule AbtDidWorkshopWeb.DemoController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop
  alias AbtDidWorkshop.{Repo, Demo, Tables.DemoTable}

  def index(conn, _) do
    changeset = Demo.changeset(%Demo{}, %{})
    demos = DemoTable.get_all()
    render(conn, "index.html", demos: demos, changeset: changeset)
  end

  def create(conn, %{"demo" => demo}) do
    case DemoTable.insert(demo) do
      {:ok, record} ->
        conn
        |> put_flash(:info, "Successfully created demo case. Now please add transactions.")
        |> redirect(to: Routes.tx_path(conn, :index, demo_id: record.id))

      {:error, changeset} ->
        demos = DemoTable.get_all()
        render(conn, "index.html", demos: demos, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => demo_id}) do
    case DemoTable.delete(demo_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Successfully deleted demo.")
        |> redirect(to: Routes.demo_path(conn, :index))

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.demo_path(conn, :index))
        |> halt()
    end
  end

  def edit(conn, %{"id" => demo_id}) do
    demo = Repo.get(Demo, demo_id)
    changeset = Demo.changeset(demo)
    render(conn, "edit.html", changeset: changeset, demo: demo)
  end

  def update(conn, %{"id" => demo_id, "demo" => new_demo}) do
    old_demo = Repo.get(Demo, demo_id)
    changeset = Demo.changeset(old_demo, new_demo)

    case Repo.update(changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Demo updated.")
        |> redirect(to: Routes.demo_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset, demo: old_demo)
    end
  end
end
