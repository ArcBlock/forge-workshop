defmodule ForgeWorkshop.Repo.Migrations.InitRepo do
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

    create table(:custodian, primary_key: false) do
      add(:address, :string, primary_key: true)
      add(:pk, :string)
      add(:sk, :string)
      add(:moniker, :string)
      add(:commission, :decimal)
      add(:charge, :decimal)
    end

    create table(:tether) do
      add(:address, :string)
      add(:deposit, :string)
      add(:exchange, :string)
      add(:withdraw, :string)
      add(:approve, :string)
    end

    create(index(:tether, [:address]))
    create(index(:tether, [:exchange]))
    create(index(:tether, [:withdraw]))
    create(index(:tether, [:approve]))
  end
end
