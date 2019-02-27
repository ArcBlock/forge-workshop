defmodule AbtDidWorkshop.Demo do
  @moduledoc """
  Represents the datastructure for demo.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias AbtDidWorkshop.Repo

  schema("demo") do
    field(:name, :string)
    field(:description, :string)
    field(:behavior, :string)
    field(:asset_content, :string)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :description, :behavior, :asset_content])
    |> validate_required([:name, :behavior])
  end

  def get_assets() do
    from(d in AbtDidWorkshop.Demo, where: d.behavior == "issue_asset")
    |> Repo.all()
  end
end
