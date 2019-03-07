defmodule AbtDidWorkshop.Demo do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AbtDidWorkshop.Tx

  schema("demo") do
    field(:title, :string)
    field(:description, :string)
    has_many(:txs, Tx, on_delete: :delete_all)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :description])
    |> validate_required([:title])
  end
end
