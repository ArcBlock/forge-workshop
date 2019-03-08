defmodule AbtDidWorkshop.Repo.Migrations.CascadeDelete do
  use Ecto.Migration

  def change do
    alter table(:tx) do
      remove(:demo_id)
      add(:demo_id, references(:demo, on_delete: :delete_all))
    end

    alter table(:tx_behavior) do
      remove(:tx_id)
      add(:tx_id, references(:tx, on_delete: :delete_all))
    end
  end
end
