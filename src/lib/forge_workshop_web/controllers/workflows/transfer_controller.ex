defmodule ForgeWorkshopWeb.TransferController do
  use ForgeWorkshopWeb, :controller
  use Hyjal, router: ForgeWorkshopWeb.Router

  require Logger

  alias ForgeWorkshopWeb.Plugs.PrepareTx
  alias ForgeWorkshop.{AssetUtil, ClaimUtil, TxUtil, Util}
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
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    [beh] = tx.tx_behaviors

    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        reply(conn, TxUtil.robert_offer(robert, user, beh.token, beh.asset))

      # When robert only demands token from the user.
      beh.behavior == "demand" and Util.empty?(beh.asset) ->
        require_sig(conn)

      # When robert demands asset from the user.
      true ->
        claim = ClaimUtil.gen_asset_claim("Please select the #{beh.asset} to transfer.")
        reply(conn, [claim], __MODULE__, :return_asset, [tx.id])
    end
  end

  def return_sig(conn, _params) do
    conn.assigns.claims
    |> ClaimUtil.find_signature_claim()
    |> case do
      nil -> reply(conn, :error, "Signature is required.")
      claim -> reply(conn, claim.origin |> TxUtil.assemble_sig(claim.sig) |> TxUtil.send_tx())
    end
  end

  def return_asset(conn, _params) do
    [beh] = conn.assigns.tx.tx_behaviors

    conn.assigns.claims
    |> ClaimUtil.find_asset_claim()
    |> case do
      nil -> reply(conn, :error, "Please provide asset address for the #{beh.asset} to transfer.")
      claim -> do_return_asset(conn, claim)
    end
  end

  defp do_return_asset(conn, claim) do
    user = conn.assigns.auth_principal
    [beh] = conn.assigns.tx.tx_behaviors

    case AssetUtil.validate_asset(beh.asset, claim.asset, user.address) do
      :ok ->
        conn
        |> Plug.Conn.assign(:asset, claim.asset)
        |> require_sig()

      {:error, reason} ->
        reply(conn, :error, reason)
    end
  end

  defp require_sig(conn) do
    claim =
      ClaimUtil.gen_signature_claim(
        conn,
        "Please confirm this transfer by signing the transaction."
      )

    reply(conn, [claim], __MODULE__, :return_sig, [conn.assigns.tx.id])
  end
end
