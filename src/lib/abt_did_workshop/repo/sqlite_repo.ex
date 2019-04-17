defmodule AbtDidWorkshop.SqliteRepo do
  @moduledoc """
  SqliteRepo connects to sqlite database
  """
  use Ecto.Repo,
    otp_app: :abt_did_workshop,
    adapter: Sqlite.Ecto2

  alias AbtDidWorkshop.Util

  def init(_type, config) do
    {:ok, Keyword.put(config, :database, get_db_file())}
  end

  defp get_db_file do
    config = Util.config("workshop")
    home = config["path"]
    "sqlite://" <> db = config["db"]
    filename = Path.join(home, db)
    ensure_db_exists(File.exists?(filename), filename)
  end

  defp ensure_db_exists(true, filename), do: filename

  defp ensure_db_exists(_, filename) do
    src_file =
      :abt_did_workshop |> Application.app_dir() |> Path.join("priv/repo/workshop.sqlite3")

    File.mkdir_p!(Path.dirname(filename))

    if File.exists?(src_file) do
      File.copy!(src_file, filename)
    end

    filename
  end
end
