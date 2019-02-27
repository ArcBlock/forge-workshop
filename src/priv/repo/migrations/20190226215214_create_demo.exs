defmodule AbtDidWorkshop.Repo.Migrations.CreateDemo do
  use Ecto.Migration

  def change do
    create table(:demo) do
      add(:name, :string)
      add(:description, :string)
      add(:behavior, :string)
      add(:asset_content, :string)
    end
  end
end
