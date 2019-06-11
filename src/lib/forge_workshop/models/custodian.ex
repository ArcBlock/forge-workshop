defmodule ForgeWorkshop.Custodian do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias ForgeWorkshop.{Repo, Custodian}

  @primary_key false
  schema("custodian") do
    field(:address, :string)
    field(:pk, :string)
    field(:sk, :string)
    field(:moniker, :string)
    field(:commission, :decimal)
    field(:charge, :decimal)
  end

  def changeset(struct, params \\ %{}) do
    incomming = %{
      address: Map.get(params, :address),
      pk: Base.encode16(Map.get(params, :pk, "")),
      sk: Base.encode16(Map.get(params, :sk, "")),
      moniker: Map.get(params, :moniker),
      commission: Map.get(params, :commission),
      charge: Map.get(params, :charge)
    }

    struct
    |> cast(incomming, [:address, :pk, :sk, :moniker, :commission, :charge])
    |> validate_required([:address, :pk, :sk, :moniker, :commission, :charge])
  end

  def insert(changeset) do
    apply(Repo, :insert, [changeset])
  end

  def get(address) do
    query = from(c in Custodian, where: c.address == ^address)

    Repo
    |> apply(:one, [query])
    |> parse()
  end

  def get_all() do
    query = from(u in Custodian)
    apply(Repo, :all, [query])
  end

  def delete_all() do
    apply(Repo, :delete_all, [from(c in Custodian)])
  end

  defp parse(nil), do: nil

  defp parse(cus) do
    %{
      address: cus.address,
      pk: Base.decode16!(cus.pk),
      sk: Base.decode16!(cus.sk),
      moniker: cus.moniker,
      commission: Decimal.to_float(cus.commission),
      charge: Decimal.to_float(cus.charge)
    }
  end
end
