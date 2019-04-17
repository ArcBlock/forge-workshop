defmodule AbtDidWorkshop.Demo do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias AbtDidWorkshop.{Demo, Repo, Tx}

  schema("demo") do
    field(:name, :string)
    field(:subtitle, :string)
    field(:description, :string)
    field(:icon, :string)
    field(:path, :string)
    field(:sk, :string)
    field(:pk, :string)
    field(:did, :string)
    has_many(:txs, Tx, on_delete: :delete_all)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :subtitle, :description, :icon, :sk, :pk, :did, :path])
    |> validate_required([:name, :icon, :path, :sk, :pk, :did])
  end

  def get(id) do
    from(
      d in Demo,
      where: d.id == ^id,
      preload: [:txs]
    )
    |> Repo.one()
  end

  def get_by_tx_id(tx_id) do
    from(
      d in Demo,
      join: t in Tx,
      on: d.id == t.demo_id,
      where: t.id == ^tx_id
    )
    |> Repo.one()
  end

  def get_all do
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
