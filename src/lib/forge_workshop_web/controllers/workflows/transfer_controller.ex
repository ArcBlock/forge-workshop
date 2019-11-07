defmodule ForgeWorkshopWeb.TransferController do
  use ForgeWorkshopWeb, :controller
  use Hyjal, router: ForgeWorkshopWeb.Router

  require Logger

  alias ForgeWorkshopWeb.Plugs.{PrepareTx, PrepareArgs}
  alias ForgeWorkshop.{AssetUtil, ClaimUtil, TxUtil, Util}
  alias Hyjal.Plugs.VerifyAuthPrincipal
  alias Hyjal.Claims.AuthPrincipal

  plug(VerifyAuthPrincipal when action != :start)
  plug(PrepareTx)
  plug(PrepareArgs)

  @impl AuthFlow
  def start(conn, _params) do
    tx = conn.assigns.tx
    info = conn.assigns.demo_info
    claim = %AuthPrincipal{description: "Please set the authentication principal."}
    reply_with_info(conn, [claim], __MODULE__, :auth_principal, [tx.id], info)
  end

  @impl AuthFlow
  def auth_principal(conn, _params) do
    tx = conn.assigns.tx
    info = conn.assigns.demo_info
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    [beh] = tx.tx_behaviors

    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        reply_with_info(conn, TxUtil.robert_offer(robert, user, beh.token, beh.asset), info)

      # When robert only demands token from the user.
      beh.behavior == "demand" and Util.empty?(beh.asset) ->
        require_sig(conn)

      # When robert demands asset from the user.
      true ->
        claim = ClaimUtil.gen_asset_claim("Please select the #{beh.asset} to transfer.")
        reply_with_info(conn, [claim], __MODULE__, :return_asset, [tx.id], info)
    end
  end

  def return_sig(conn, _params) do
    info = conn.assigns.demo_info

    conn.assigns.claims
    |> ClaimUtil.find_signature_claim()
    |> case do
      nil ->
        reply_with_info(conn, :error, "Signature is required.", info)

      claim ->
        reply_with_info(
          conn,
          claim.origin |> TxUtil.assemble_sig(claim.sig) |> TxUtil.send_tx(),
          info
        )
    end
  end

  def return_asset(conn, _params) do
    info = conn.assigns.demo_info
    [beh] = conn.assigns.tx.tx_behaviors

    conn.assigns.claims
    |> ClaimUtil.find_asset_claim()
    |> case do
      nil ->
        reply_with_info(
          conn,
          :error,
          "Please provide asset address for the #{beh.asset} to transfer.",
          info
        )

      claim ->
        do_return_asset(conn, claim)
    end
  end

  defp do_return_asset(conn, claim) do
    info = conn.assigns.demo_info
    user = conn.assigns.auth_principal
    [beh] = conn.assigns.tx.tx_behaviors

    case AssetUtil.validate_asset(beh.asset, claim.asset, user.address) do
      :ok ->
        conn
        |> Plug.Conn.assign(:asset, claim.asset)
        |> require_sig()

      {:error, reason} ->
        reply_with_info(conn, :error, reason, info)
    end
  end

  defp require_sig(conn) do
    info = conn.assigns.demo_info

    claim =
      ClaimUtil.gen_signature_claim(
        conn,
        "Please confirm this transfer by signing the transaction."
      )

    reply_with_info(conn, [claim], __MODULE__, :return_sig, [conn.assigns.tx.id], info)
  end
end
