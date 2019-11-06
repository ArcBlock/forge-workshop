defmodule ForgeWorkshopWeb.Plugs.PrepareTx do
  @moduledoc """
  Prepare common arguments.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias ForgeWorkshop.{Demo, Tx, Util}
  alias ForgeWorkshopWeb.Router.Helpers, as: Routes

  def init(_) do
  end

  def call(%Plug.Conn{params: %{"id" => id}} = conn, _) do
    tx_id = String.to_integer(id)

    conn =
      case Tx.get(tx_id) do
        nil ->
          conn
          |> json({:error, "Cannot find transaction."})
          |> halt()

        tx ->
          conn
          |> assign(:tx, tx)
      end

    demo = Demo.get_by_tx_id(tx_id)
    config = ArcConfig.read_config(:forge_workshop)
    chain_config = config["hyjal"]["chain"]

    demo_info = %{
      app_name: demo.name,
      app_desc: demo.description,
      app_logo: Routes.static_url(conn, demo.icon),
      chain_host: "#{chain_config["host"]}:#{chain_config["port"]}/api/",
      sk: Util.str_to_bin(demo.sk),
      pk: Util.str_to_bin(demo.pk),
      did: Util.did_to_address(demo.did)
    }

    assign(conn, :demo_info, demo_info)
  end
end
