defmodule AbtDidWorkshop.TxBehavior do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AbtDidWorkshop.Tx

  schema("tx_behavior") do
    field(:tx_type, :string)
    field(:behavior, :string)
    field(:token, :integer)
    field(:asset, :string)
    field(:function, :string)
    field(:description, :string)
    belongs_to(:tx, Tx)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:tx_type, :behavior, :token, :asset, :function, :description])
    |> validate_required([:tx_type, :behavior, :description])
  end
end
