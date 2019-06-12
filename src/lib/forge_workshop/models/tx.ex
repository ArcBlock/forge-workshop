defmodule ForgeWorkshop.Tx do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto
  import Ecto.Changeset
  import Ecto.Query

  alias ForgeWorkshop.{Demo, Repo, Tx, TxBehavior}

  schema("tx") do
    field(:name, :string)
    field(:description, :string)
    field(:tx_type, :string)
    belongs_to(:demo, Demo)
    has_many(:tx_behaviors, TxBehavior, on_delete: :delete_all)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :description, :tx_type])
    |> validate_required([:name, :description, :tx_type])
  end

  def get_all(demo_id) do
    query =
      from(
        t in Tx,
        where: t.demo_id == ^demo_id,
        preload: [:tx_behaviors]
      )

    apply(Repo, :all, [query])
  end

  def get(id) do
    query =
      from(
        t in Tx,
        preload: [:tx_behaviors],
        where: t.id == ^id
      )

    apply(Repo, :one, [query])
  end

  def get_offer_txs(demo_id) do
    query =
      from(
        t in Tx,
        join: b in TxBehavior,
        on: t.id == b.tx_id and b.behavior == "offer" and b.asset != "",
        where: t.demo_id == ^demo_id,
        preload: [:tx_behaviors]
      )

    apply(Repo, :all, [query])
  end

  def upsert(tx, "", demo_id) do
    upsert(tx, -1, demo_id)
  end

  def upsert(tx, tx_id, demo_id) do
    apply(Repo, :transaction, [
      fn ->
        delete(tx_id)

        changeset =
          demo_id
          |> Demo.get()
          |> build_assoc(:txs)
          |> Tx.changeset(tx)

        tx_record = apply(Repo, :insert!, [changeset])

        tx.tx_behaviors
        |> Enum.each(fn b ->
          changeset =
            tx_record
            |> build_assoc(:tx_behaviors)
            |> TxBehavior.changeset(b)

          apply(Repo, :insert!, [changeset])
        end)
      end
    ])
  end

  def delete(nil), do: :ok
  def delete(""), do: :ok

  def delete(id) when is_binary(id) do
    id
    |> String.to_integer()
    |> delete()
  end

  def delete(id) do
    case get(id) do
      nil -> :ok
      tx -> apply(Repo, :delete, [tx])
    end
  end
end
