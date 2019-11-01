defmodule ForgeWorkshopWeb.ExchangeController do
  use ForgeWorkshopWeb, :controller
  use Hyjal, router: ForgeWorkshopWeb.Router

  require Logger

  alias ForgeWorkshopWeb.Plugs.PrepareTx
  alias ForgeWorkshop.{AssetUtil, ClaimUtil, Util, TxUtil}
  alias Hyjal.Plugs.VerifyAuthPrincipal
  alias Hyjal.Claims.AuthPrincipal

  plug(VerifyAuthPrincipal when action != :start)
  plug(PrepareTx)

  @impl AuthFlow
  def start(conn, _params) do
    tx = conn.assigns.tx
    claim = %AuthPrincipal{description: "Please set the authentication principal."}
    reply(conn, [claim], __MODULE__, :auth_principal, [tx.id])
  end

  @impl AuthFlow
  def auth_principal(conn, _params) do
    tx = conn.assigns.tx
    tx_behaviors = tx.tx_behaviors

    demand = Enum.find(tx_behaviors, fn beh -> beh.behavior == "demand" end)

    case Util.empty?(demand.asset) do
      # When robert does not demand asset from the user.
      true ->
        require_multi_sig(conn)

      # When robert demands asset from the user.
      false ->
        claim = ClaimUtil.gen_asset_claim("Please select the #{demand.asset} to exchange.")
        reply(conn, [claim], __MODULE__, :return_asset, [tx.id])
    end
  end

  def return_sig(conn, _params) do
    conn.assigns.claims
    |> ClaimUtil.find_signature_claim()
    |> case do
      nil ->
        reply(conn, :error, "Signature is required.")

      claim ->
        reply(conn, claim.origin |> TxUtil.assemble_multi_sig(claim.sig) |> TxUtil.send_tx())
    end
  end

  def return_asset(conn, _params) do
    tx = conn.assigns.tx
    demand = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "demand" end)

    conn.assigns.claims
    |> ClaimUtil.find_asset_claim()
    |> case do
      nil ->
        reply(conn, :error, "Please provide asset address of the #{demand.asset} to exchange.")

      claim ->
        do_return_asset(conn, claim, demand)
    end
  end

  defp do_return_asset(conn, claim, demand) do
    user = conn.assigns.auth_principal

    case AssetUtil.validate_asset(demand.asset, claim.asset, user.address) do
      :ok ->
        conn
        |> Plug.Conn.assign(:asset, claim.asset)
        |> require_multi_sig()

      {:error, reason} ->
        reply(conn, :error, reason)
    end
  end

  defp require_multi_sig(conn) do
    claim =
      ClaimUtil.gen_multi_sig_claim(
        conn,
        "Please confirm this exchange by signing the transaction."
      )

    reply(conn, [claim], __MODULE__, :return_sig, [conn.assigns.tx.id])
  end
end
