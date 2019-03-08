defmodule AbtDidWorkshop.Application do
  @moduledoc false

  alias AbtDidWorkshopWeb.Endpoint

  def start(_type, _args) do
    children = get_children()
    register_type_urls()
    opts = [strategy: :one_for_one, name: AbtDidWorkshop.Supervisor]
    result = Supervisor.start_link(children, opts)
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
      {:certificate, "ws:x:certificate", AbtDidWorkshop.Certificate}
    ])
  end

  def get_children do
    app_servers1 = [
      AbtDidWorkshopWeb.Endpoint,
      AbtDidWorkshop.UserDb,
      AbtDidWorkshop.AssetsDb,
      AbtDidWorkshop.Repo
    ]

    app_servers2 = [AbtDidWorkshop.AppState]

    filename = :abt_did_workshop |> Application.app_dir() |> Path.join("priv/forge.toml")
    forge_servers = ForgeSdk.init(:abt_did_workshop, "", filename)

    case Application.get_env(:abt_did_workshop, :env) do
      "test" -> app_servers1
      _ -> forge_servers ++ app_servers1 ++ app_servers2
    end
  end
end
