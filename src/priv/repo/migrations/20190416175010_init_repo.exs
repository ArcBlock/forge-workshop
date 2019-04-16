defmodule AbtDidWorkshop.Repo.Migrations.InitRepo do
  use Ecto.Migration

  def change do
    create table(:app_state) do
      add(:name, :string)
      add(:subtitle, :string)
      add(:description, :string)
      add(:icon, :string)
      add(:copyright, :string)
      add(:publisher, :string)
      add(:path, :string)
      add(:sk, :string)
      add(:pk, :string)
      add(:did, :string)
      add(:claims, :jsonb)
    end

    create table(:demo) do
      add(:name, :string)
      add(:subtitle, :string)
      add(:description, :string)
      add(:icon, :string)
      add(:sk, :string)
      add(:pk, :string)
      add(:did, :string)
      add(:path, :string)
    end

    create table(:tx) do
      add(:name, :string)
      add(:description, :string)
      add(:tx_type, :string)
      add(:demo_id, references(:demo, on_delete: :delete_all))
    end

    create table(:tx_behavior) do
      add(:tx_type, :string)
      add(:behavior, :string)
      add(:token, :integer)
      add(:asset, :string)
      add(:tx_id, references(:tx, on_delete: :delete_all))
      add(:function, :string)
      add(:description, :string)
    end

    create table(:user) do
      add(:did, :string)
      add(:pk, :string)
      add(:claim, :map)
    end
  end
end