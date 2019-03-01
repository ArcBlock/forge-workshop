defmodule AbtDidWorkshop.Tx do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AbtDidWorkshop.{Demo, TxBehavior}

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
end
