defmodule AbtDidWorkshop.Application do
  @moduledoc false

  alias AbtDidWorkshop.{Repo, UserDb, Util, WalletUtil, WorkshopAsset}
  alias AbtDidWorkshopWeb.Endpoint

  def start(_type, _args) do
    children = get_children()
    register_type_urls()
    opts = [strategy: :one_for_one, name: AbtDidWorkshop.Supervisor]
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
    ForgeAbi.register_type_urls([
      {:workshop_asset, "ws:x:workshop_asset", WorkshopAsset}
    ])
  end

  def get_children do
    env = Util.config(:env)
    app_servers = [Endpoint, UserDb, Repo]

    case env do
      "test" ->
        app_servers

      _ ->
        filename =
          :abt_did_workshop
          |> Application.app_dir()
          |> Path.join("priv/forge_config")
          |> Path.join("/forge.toml")

        forge_servers = ForgeSdk.init(:abt_did_workshop, "", filename)
        forge_servers ++ app_servers
    end
  end
end
