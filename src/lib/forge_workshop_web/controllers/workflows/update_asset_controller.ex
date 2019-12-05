defmodule ForgeWorkshopWeb.UpdateAssetController do
  use ForgeWorkshopWeb, :controller
  use Hyjal, router: ForgeWorkshopWeb.Router

  require Logger

  alias ForgeWorkshopWeb.Plugs.{PrepareTx, PrepareArgs}
  alias ForgeWorkshop.{AssetUtil, ClaimUtil, TxUtil}
  alias Hyjal.Plugs.VerifyAuthPrincipal
  alias Hyjal.Claims.AuthPrincipal

  plug(VerifyAuthPrincipal when action != :start)
  plug(PrepareTx)
  plug(PrepareArgs)

  @impl AuthFlow
  def start(conn, _params) do
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    claim = %AuthPrincipal{description: "Please set the authentication principal."}
    reply_with_info(conn, [claim], __MODULE__, :auth_principal, [tx.id], info)
  end

  @impl AuthFlow
  def auth_principal(conn, _params) do
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    tx_behaviors = tx.tx_behaviors
    update = Enum.find(tx_behaviors, fn beh -> beh.behavior == "update" end)
    claim = ClaimUtil.gen_asset_claim("Please select the #{update.asset} to update.")
    reply_with_info(conn, [claim], __MODULE__, :return_asset, [tx.id], info)
  end

  def return_sig(conn, _params) do
    info = conn.assigns.hyjal_info
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    offer = Enum.find(conn.assigns.tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)

    conn.assigns.claims
    |> ClaimUtil.find_signature_claim()
    |> case do
      nil ->
        reply_with_info(conn, :error, "Signature is required.")

      claim ->
        result = claim.origin |> TxUtil.assemble_sig(claim.sig) |> TxUtil.send_tx()
        TxUtil.async_offer(result, robert, user, offer)
        reply_with_info(conn, result, info)
    end
  end

  def return_asset(conn, _params) do
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    update = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "update" end)

    conn.assigns.claims
    |> ClaimUtil.find_asset_claim()
    |> case do
      nil ->
        reply_with_info(
          conn,
          :error,
          "Please provide asset address of the #{update.asset} to update.",
          info
        )

      claim ->
        do_return_asset(conn, claim, update)
    end
  end

  defp do_return_asset(conn, claim, update) do
    info = conn.assigns.hyjal_info
    user = conn.assigns.auth_principal

    case AssetUtil.validate_asset(update.asset, claim.asset, user.address) do
      :ok ->
        conn
        |> Plug.Conn.assign(:asset, claim.asset)
        |> require_multi_sig()

      {:error, reason} ->
        reply_with_info(conn, :error, reason, info)
    end
  end

  defp require_multi_sig(conn) do
    info = conn.assigns.hyjal_info

    claim =
      ClaimUtil.gen_signature_claim(
        conn,
        "Please confirm this update by signing the transaction."
      )

    reply_with_info(conn, [claim], __MODULE__, :return_sig, [conn.assigns.tx.id], info)
  end
end
