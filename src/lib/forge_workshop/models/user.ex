defmodule ForgeWorkshop.User do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema("user") do
    field(:did, :string)
    field(:pk, :string)
    field(:claim, :map)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:did, :description, :tx_type])
    |> validate_required([:name, :description, :tx_type])
  end
end
