defmodule AbtDidWorkshop.Repo.Migrations.AddAppState do
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
    end
  end
end
