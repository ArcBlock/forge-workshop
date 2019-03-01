defmodule AbtDidWorkshop.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:demo) do
      add(:title, :string)
      add(:description, :string)
    end

    create table(:tx) do
      add(:name, :string)
      add(:description, :string)
      add(:tx_type, :string)
      add(:demo_id, references(:demo))
    end

    create table(:tx_behavior) do
      add(:tx_type, :string)
      add(:behavior, :string)
      add(:token, :integer)
      add(:asset_content, :string)
      add(:tx_id, references(:tx))
    end

    create table(:user) do
      add(:did, :string)
      add(:pk, :string)
      add(:claim, :map)
    end
  end
end
