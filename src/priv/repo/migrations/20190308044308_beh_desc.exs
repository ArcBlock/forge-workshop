defmodule AbtDidWorkshop.Repo.Migrations.BehDesc do
  use Ecto.Migration

  def change do
    alter table(:tx_behavior) do
      add(:description, :string)
    end
  end
end
