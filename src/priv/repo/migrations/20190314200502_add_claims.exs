defmodule AbtDidWorkshop.Repo.Migrations.AddClaims do
  use Ecto.Migration

  def change do
    alter table(:app_state) do
      add(:claims, :jsonb)
    end
  end
end
