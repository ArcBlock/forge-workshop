defmodule AbtDidWorkshop.AppAuthState do
  @moduledoc """
  Represents the datastructure for AppAuthState.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema("app_state") do
    field(:name, :string)
    field(:subtitle, :string)
    field(:description, :string)
    field(:icon, :string)
    field(:copyright, :string)
    field(:publisher, :string)
    field(:path, :string)
    field(:sk, :string)
    field(:pk, :string)
    field(:did, :string)
    field(:claims, :map)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [
      :name,
      :subtitle,
      :description,
      :icon,
      :copyright,
      :publisher,
      :path,
      :sk,
      :pk,
      :did,
      :claims
    ])
    |> validate_required([:name, :subtitle, :description, :icon, :path, :sk, :pk, :did])
  end

  def get_info(nil), do: %{}

  def get_info(state) do
    Map.take(state, [:name, :subtitle, :description, :icon, :copyright, :publisher, :path])
  end
end
