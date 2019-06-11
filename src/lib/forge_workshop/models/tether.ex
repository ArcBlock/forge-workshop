defmodule ForgeWorkshop.Tether do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias ForgeWorkshop.{Repo, Tether}

  schema("tether") do
    field(:address, :string)
    field(:deposit, :string)
    field(:exchange, :string)
    field(:withdraw, :string)
    field(:approve, :string)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:address, :deposit, :exchange, :withdraw, :approve])
    |> validate_required([:address])
  end

  def get_all() do
    query = from(t in Tether)
    apply(Repo, :all, [query])
  end

  def get_by_tether(address) do
    query =
      from(
        d in Tether,
        where: d.address == ^address
      )

    apply(Repo, :all, [query])
  end

  def get_by_exchanges(exchanges) do
    query =
      from(
        d in Tether,
        where: d.exchange in ^exchanges
      )

    apply(Repo, :all, [query])
  end

  def get_by_withdraws(withdraws) do
    query =
      from(
        d in Tether,
        where: d.withdraw in ^withdraws
      )

    apply(Repo, :all, [query])
  end

  def insert(tether) do
    changeset = Tether.changeset(%Tether{}, tether)
    apply(Repo, :insert, [changeset])
  end

  def update(changeset) do
    apply(Repo, :update, [changeset])
  end
end
