defmodule ForgeWorkshop.Application do
  @moduledoc false

  alias ForgeWorkshop.{Repo, SqliteRepo, UserDb, Util, WalletUtil, WorkshopAsset}
  alias ForgeWorkshopWeb.Endpoint

  def start(_type, _args) do
    callback = fn ->
      forge_state = ForgeSdk.get_forge_state()
      ForgeSdk.update_type_url(forge_state)
      register_type_urls()
    end

    children = get_servers(callback)
    opts = [strategy: :one_for_one, name: ForgeWorkshop.Supervisor]
    result = Supervisor.start_link(children, opts)

    spawn(fn ->
      Process.sleep(5_000)
      %{decimal: decimal} = ForgeSdk.get_forge_state().token
      Application.put_env(:forge_abi, :decimal, decimal)
      robert = WalletUtil.get_robert()
      WalletUtil.declare_wallet(robert, "robert", Util.remote_chan())
      WalletUtil.raise_validator_power()
      WalletUtil.declare_anchors()
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

  defp get_servers(callback) do
    env = Util.config(:env)
    app_servers = get_app_servers()
    forge_servers = get_forge_servers(callback)

    case env do
      "test" ->
        app_servers

      _ ->
        forge_servers ++ app_servers
    end
  end

  defp get_app_servers() do
    read_config()
    repo = set_db()
    [Endpoint, UserDb, repo]
  end

  defp get_forge_servers(callback) do
    filepath = Util.config(["workshop", "local_forge"])
    [{mod, sock}] = ForgeSdk.init(:forge_workshop, "", filepath)
    Application.put_env(:forge_workshop, :local_chan, ForgeSdk.get_chan())
    Util.remote_chan()
    [{mod, addr: sock, callback: callback}]
  end

  def read_config() do
    filepath =
      case System.get_env("WORKSHOP_CONFIG") do
        nil -> :forge_workshop |> Application.app_dir() |> Path.join("priv/config/default.toml")
        path -> path
      end

    filepath
    |> File.read!()
    |> Toml.decode!()
    |> Enum.each(fn {key, value} ->
      Application.put_env(:forge_workshop, key, adjust_config(value))
    end)
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
