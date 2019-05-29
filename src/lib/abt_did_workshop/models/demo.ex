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
    query =
      from(d in Demo,
        where: d.id == ^id,
        preload: [:txs]
      )

    apply(Repo, :one, [query])
  end

  def get_by_tx_id(tx_id) do
    query =
      from(
        d in Demo,
        join: t in Tx,
        on: d.id == t.demo_id,
        where: t.id == ^tx_id
      )

    apply(Repo, :one, [query])
  end

  def get_all do
    query =
      from(
        d in Demo,
        preload: [:txs]
      )

    apply(Repo, :all, [query])
  end

  def insert(demo) do
    changeset = Demo.changeset(%Demo{}, demo)
    apply(Repo, :insert, [changeset])
  end

  def delete(id) do
    apply(Repo, :delete, [get(id)])
  end

  def update(id, param) do
    changeset =
      id
      |> get()
      |> Demo.changeset(param)

    apply(Repo, :update, [changeset])
  end
end
