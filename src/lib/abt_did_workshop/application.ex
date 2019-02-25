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

    opts = [strategy: :one_for_one, name: AbtDidWorkshop.Supervisor]
    Supervisor.start_link(children, opts)
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
end
