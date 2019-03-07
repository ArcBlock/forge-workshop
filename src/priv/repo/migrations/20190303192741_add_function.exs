defmodule AbtDidWorkshop.Repo.Migrations.AddFunction do
  use Ecto.Migration

  def change do
    alter table(:tx_behavior) do
      add(:function, :string)
    end
  end
end
