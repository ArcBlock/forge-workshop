defmodule AbtDidWorkshop.Tables.DemoTable do
  import Ecto.Query

  alias AbtDidWorkshop.{Demo, Repo}

  def get(id) do
    from(
      d in Demo,
      where: d.id == ^id,
      preload: [:txs]
    )
    |> Repo.one()
  end

  def get_all() do
    from(
      d in Demo,
      preload: [:txs]
    )
    |> Repo.all()
  end

  def insert(demo) do
    %Demo{}
    |> Demo.changeset(demo)
    |> Repo.insert()
  end

  def delete(id) do
    id
    |> get()
    |> Repo.delete()
  end

  def update(id, param) do
    id
    |> get()
    |> Demo.changeset(param)
    |> Repo.update()
  end
end
