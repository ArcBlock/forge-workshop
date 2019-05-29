defmodule AbtDidWorkshop.AppState do
  @moduledoc """
  Represents the datastructure for AppState.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias AbtDidWorkshop.{AppState, Util}
  alias AbtDidWorkshop.Repo

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
    chain_info = ForgeSdk.get_chain_info()
    forge_state = ForgeSdk.get_forge_state()

    state
    |> Map.take([:name, :subtitle, :description, :icon, :copyright, :publisher, :path])
    |> Map.merge(%{
      chainId: chain_info.network,
      chainVersion: chain_info.version,
      chainHost: Util.get_chainhost(),
      chainToken: forge_state.token.symbol,
      decimals: forge_state.token.decimal
    })
  end

  def get do
    Repo
    |> apply(:all, [from(a in AppState)])
    |> List.first()
  end

  def delete do
    apply(Repo, :delete_all, [from(a in AppState)])
  end

  def insert(state) do
    changeset = AppState.changeset(%AppState{}, state)
    apply(Repo, :insert, [changeset])
  end
end
