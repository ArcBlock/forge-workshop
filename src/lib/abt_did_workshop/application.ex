defmodule AbtDidWorkshop.Application do
  @moduledoc false

  alias AbtDidWorkshop.{Repo, SqliteRepo, UserDb, Util, WalletUtil, WorkshopAsset}
  alias AbtDidWorkshopWeb.Endpoint

  def start(_type, _args) do
    children = get_children()
    opts = [strategy: :one_for_one, name: AbtDidWorkshop.Supervisor]
    result = Supervisor.start_link(children, opts)

    forge_state = ForgeSdk.get_forge_state()
    ForgeSdk.update_type_url(forge_state)
    register_type_urls()

    spawn(fn ->
      Process.sleep(5_000)
      %{decimal: decimal} = ForgeSdk.get_forge_state().token
      Application.put_env(:forge_abi, :decimal, decimal)
      WalletUtil.get_robert()
    end)

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  defp register_type_urls do
    ForgeAbi.add_type_urls([
      {"ws:x:workshop_asset", WorkshopAsset}
    ])
  end

  defp get_children do
    filepath = read_config()
    env = Util.config(:env)
    repo = set_db()
    app_servers = [Endpoint, UserDb, repo]

    case env do
      "test" ->
        app_servers

      _ ->
        forge_servers = ForgeSdk.init(:abt_did_workshop, "", filepath)
        forge_servers ++ app_servers
    end
  end

  def read_config() do
    filepath =
      case System.get_env("WORKSHOP_CONFIG") do
        nil -> :abt_did_workshop |> Application.app_dir() |> Path.join("priv/config/default.toml")
        path -> path
      end

    filepath
    |> File.read!()
    |> Toml.decode!()
    |> Enum.each(fn {key, value} ->
      Application.put_env(:abt_did_workshop, key, adjust_config(value))
    end)

    filepath
  end

  defp adjust_config(config) when is_map(config) do
    config
    |> Enum.map(fn {key, value} -> {key, adjust_config(key, value)} end)
    |> Enum.into(%{})
  end

  defp adjust_config("path", value), do: Path.expand(value)
  defp adjust_config(_, value), do: value

  defp set_db() do
    db_path = Util.config(["workshop", "db"])

    case db_path do
      "sqlite://" <> _ ->
        Repo.set_mod(SqliteRepo)
        SqliteRepo
        # "postgres://" <>
    end
  end
end
