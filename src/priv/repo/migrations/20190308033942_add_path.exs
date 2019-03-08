defmodule AbtDidWorkshop.Repo.Migrations.AddPath do
  use Ecto.Migration

  def change do
    alter table(:demo) do
      add(:path, :string)
    end
  end
end
