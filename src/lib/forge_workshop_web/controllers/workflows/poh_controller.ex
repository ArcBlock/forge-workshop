defmodule ForgeWorkshopWeb.PohController do
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
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    poh = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "poh" end)

    claim =
      case Util.empty?(poh.token) do
        true ->
          %AuthPrincipal{description: "Please set the authentication principal."}

        false ->
          %AuthPrincipal{
            description:
              "Please set the authentication principal with minimal #{poh.token} token."
          }
      end

    reply_with_info(conn, [claim], __MODULE__, :auth_principal, [tx.id], info)
  end

  @impl AuthFlow
  def auth_principal(conn, _params) do
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    poh = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "poh" end)

    case Util.empty?(poh.token) do
      false ->
        validate_token(conn, poh)

      true ->
        claim =
          ClaimUtil.gen_asset_claim("Please return the address of a #{poh.asset} owned by you.")

        reply_with_info(conn, [claim], __MODULE__, :return_asset, [tx.id], info)
    end
  end

  def return_asset(conn, _params) do
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    poh = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "poh" end)

    conn.assigns.claims
    |> ClaimUtil.find_asset_claim()
    |> case do
      nil ->
        reply_with_info(
          conn,
          :error,
          "Please return the address of a #{poh.asset} owned by you.",
          info
        )

      claim ->
        do_return_asset(conn, claim, poh)
    end
  end

  defp do_return_asset(conn, claim, poh) do
    info = conn.assigns.hyjal_info
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    offer = Enum.find(conn.assigns.tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)

    case AssetUtil.validate_asset(poh.asset, claim.asset, user.address) do
      :ok ->
        result = TxUtil.robert_offer(robert, user, offer)
        reply_with_info(conn, result, info)

      {:error, reason} ->
        reply_with_info(conn, :error, reason, info)
    end
  end

  defp validate_token(conn, poh) do
    info = conn.assigns.hyjal_info
    tx = conn.assigns.tx
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    offer = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)
    account_state = ForgeSdk.get_account_state(address: user.address)

    cond do
      account_state == nil ->
        reply_with_info(
          conn,
          :error,
          "Cannot find account state by address #{user.address}.",
          info
        )

      ForgeAbi.unit_to_token(account_state.balance) < poh.token ->
        reply_with_info(
          conn,
          :error,
          "The account does not have enough balance.",
          info
        )

      Util.empty?(poh.asset) == false ->
        claim =
          ClaimUtil.gen_asset_claim("Please return the address of a #{poh.asset} owned by you.")

        reply_with_info(conn, [claim], __MODULE__, :return_asset, [tx.id], info)

      true ->
        result = TxUtil.robert_offer(robert, user, offer)
        reply_with_info(conn, result, info)
    end
  end
end
