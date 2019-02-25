defmodule AbtDidWorkshop.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias AbtDidWorkshopWeb.Endpoint

  def start(_type, _args) do
    filename = :abt_did_workshop |> Application.app_dir() |> Path.join("priv/forge.toml")
    servers = ForgeSdk.init(:cert, "", filename)

    children =
      servers ++
        [
          AbtDidWorkshopWeb.Endpoint,
          AbtDidWorkshop.UserDb,
          AbtDidWorkshop.AppState
        ]

    register_type_urls()
    opts = [strategy: :one_for_one, name: AbtDidWorkshop.Supervisor]
    result = Supervisor.start_link(children, opts)
    init_certs()
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

  defp init_certs do
    {robert, _} = AbtDidWorkshop.WalletUtil.init_robert()
    Process.sleep(5000)
    AbtDidWorkshop.AssetUtil.init_certs(robert, "ABT", 40)
  end
end
