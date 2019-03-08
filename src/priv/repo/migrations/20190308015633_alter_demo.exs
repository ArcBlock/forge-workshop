defmodule AbtDidWorkshop.Repo.Migrations.AlterDemo do
  use Ecto.Migration

  def change do
    alter table(:demo) do
      remove(:title)
      add(:name, :string)
      add(:subtitle, :string)
      add(:icon, :string)
      add(:sk, :string)
      add(:pk, :string)
      add(:did, :string)
    end
  end
end
