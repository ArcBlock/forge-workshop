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
    env = Application.get_env(:abt_did_workshop, :env)

    forge_env =
      case env do
        env when env in ["test", "dev"] -> "dev"
        _ -> "staging"
      end

    app_servers1 = [
      AbtDidWorkshopWeb.Endpoint,
      AbtDidWorkshop.UserDb,
      AbtDidWorkshop.AssetsDb,
      AbtDidWorkshop.Repo
    ]

    case env do
      "test" ->
        app_servers1

      _ ->
        filename =
          :abt_did_workshop
          |> Application.app_dir()
          |> Path.join("priv/forge_config")
          |> Path.join("/forge_#{forge_env}.toml")

        forge_servers = ForgeSdk.init(:abt_did_workshop, "", filename)
        forge_servers ++ app_servers1 ++ [AbtDidWorkshop.AppState]
    end
  end
end
