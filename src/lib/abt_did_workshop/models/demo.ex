defmodule AbtDidWorkshop.Demo do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AbtDidWorkshop.Tx

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
end
