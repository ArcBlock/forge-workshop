defmodule ForgeWorkshop.Application do
  @moduledoc false

  alias ForgeWorkshop.{Repo, SqliteRepo, UserDb, WalletUtil, WorkshopAsset}
  alias ForgeWorkshopWeb.Endpoint

  def start(_type, _args) do
    ArcConfig.read_config(:forge_workshop)
    read_config()
    apply_endpoint_config()
    connect_local_forge()
    children = get_servers()
    opts = [strategy: :one_for_one, name: ForgeWorkshop.Supervisor]
    result = Supervisor.start_link(children, opts)

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

  defp get_servers() do
    repo = set_db()
    [Endpoint, UserDb, repo]
  end

  defp connect_local_forge() do
    config = ArcConfig.read_config(:forge_workshop)
    local_forge_sock = config["workshop"]["local_forge"]
    ForgeSdk.connect(local_forge_sock, name: "local", default: true)
    register_type_urls()
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

  defp apply_endpoint_config() do
    config = ArcConfig.read_config(:forge_workshop)
    schema = config["workshop"]["schema"]
    port = config["workshop"]["port"]
    host = config["workshop"]["host"]

    endpoint = Application.get_env(:forge_workshop, ForgeWorkshopWeb.Endpoint)
    endpoint = Keyword.put(endpoint, :url, host: host, port: port)

    endpoint =
      case schema do
        "https" ->
          Keyword.update(endpoint, :https, [port: port], fn v -> Keyword.put(v, :port, port) end)

        "http" ->
          Keyword.update(endpoint, :http, [port: port], fn v -> Keyword.put(v, :port, port) end)
      end

    Application.put_env(:forge_workshop, ForgeWorkshopWeb.Endpoint, endpoint)
  end

  defp set_db() do
    config = ArcConfig.read_config(:forge_workshop)
    db_path = config["workshop"]["db"]

    case db_path do
      "sqlite://" <> _ ->
        Repo.set_mod(SqliteRepo)
        SqliteRepo
        # "postgres://" <>
    end
  end
end
