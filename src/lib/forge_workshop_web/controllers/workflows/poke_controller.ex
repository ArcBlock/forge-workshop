defmodule ForgeWorkshopWeb.PokeController do
  use ForgeWorkshopWeb, :controller
  use Hyjal, router: ForgeWorkshopWeb.Router

  require Logger

  alias ForgeWorkshopWeb.Plugs.PrepareTx
  alias ForgeWorkshop.{ClaimUtil, TxUtil}
  alias Hyjal.Plugs.VerifyAuthPrincipal
  alias Hyjal.Claims.AuthPrincipal

  plug(VerifyAuthPrincipal when action != :start)
  plug(PrepareTx)

  @impl AuthFlow
  def start(conn, _params) do
    tx = conn.assigns.tx
    info = conn.assigns.demo_info
    claim = %AuthPrincipal{description: "Please set the authentication principal."}
    reply_with_info(conn, [claim], __MODULE__, :auth_principal, [tx.id], info)
  end

  @impl AuthFlow
  def auth_principal(conn, _params) do
    claim =
      ClaimUtil.gen_signature_claim(conn, "Please confirm this poke by signing the transaction.")

    info = conn.assigns.demo_info
    reply_with_info(conn, [claim], __MODULE__, :return_sig, [conn.assigns.tx.id], info)
  end

  def return_sig(conn, _params) do
    info = conn.assigns.demo_info

    conn.assigns.claims
    |> ClaimUtil.find_signature_claim()
    |> case do
      nil ->
        reply_with_info(conn, :error, "Signature is required.")

      claim ->
        reply_with_info(
          conn,
          claim.origin |> TxUtil.assemble_sig(claim.sig) |> TxUtil.send_tx(),
          info
        )
    end
  end
end
