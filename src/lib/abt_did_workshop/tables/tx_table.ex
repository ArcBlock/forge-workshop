defmodule AbtDidWorkshop.Tables.TxTable do
  @moduledoc false

  import Ecto
  import Ecto.Query

  alias AbtDidWorkshop.{Repo, Tables.DemoTable, Tx, TxBehavior}

  def get_all(demo_id) do
    from(
      t in Tx,
      where: t.demo_id == ^demo_id,
      preload: [:tx_behaviors]
    )
    |> Repo.all()
  end

  def get(id) do
    from(
      t in Tx,
      preload: [:tx_behaviors],
      where: t.id == ^id
    )
    |> Repo.one()
  end

  def get_offer_txs(demo_id) do
    from(
      t in Tx,
      join: b in TxBehavior,
      on: t.id == b.tx_id and b.behavior == "offer" and b.asset != "",
      where: t.demo_id == ^demo_id,
      preload: [:tx_behaviors]
    )
    |> Repo.all()
  end

  def upsert(tx, tx_id, demo_id) do
    Repo.transaction(fn ->
      delete(tx_id)

      tx_record =
        demo_id
        |> DemoTable.get()
        |> build_assoc(:txs)
        |> Tx.changeset(tx)
        |> Repo.insert!()

      tx.tx_behaviors
      |> Enum.each(fn b ->
        build_assoc(tx_record, :tx_behaviors)
        |> TxBehavior.changeset(b)
        |> Repo.insert!()
      end)
    end)
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
      tx -> Repo.delete(tx)
    end
  end
end
