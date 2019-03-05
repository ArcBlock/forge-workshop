defmodule AbtDidWorkshopWeb.TransactionController do
  @moduledoc """
  Executes transactions.
  """

  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{
    AppState,
    Plugs.VerifySig,
    Tables.TxTable,
    Tx.Exchange,
    Tx.Helper,
    Tx.Transfer,
    Tx.Update,
    TxBehavior,
    Util,
    WalletUtil
  }

  plug(VerifySig when action in [:response])

  def request(conn, %{"id" => id, "userDid" => did}) do
    tx_id = String.to_integer(id)
    user_addr = Util.did_to_address(did)
    {robert, _} = WalletUtil.init_robert()

    case TxTable.get(tx_id) do
      nil ->
        json(conn, {:error, "Cannot find transaction."})

      tx ->
        tx.tx_type
        |> do_request(tx.tx_behaviors, robert, user_addr)
        |> reply(conn, tx_id)
    end
  end

  def response(conn, %{"id" => id}) do
    tx_id = String.to_integer(id)
    user_addr = conn.assigns.did
    claims = conn.assigns.claims
    {robert, _} = WalletUtil.init_robert()

    case TxTable.get(tx_id) do
      nil ->
        json(conn, {:error, "Cannot find transaction."})

      tx ->
        tx.tx_type
        |> do_response(tx.tx_behaviors, claims, robert, user_addr)
        |> reply(conn, tx_id)
    end
  end

  defp do_request(_, behaviors, _, _) when is_nil(behaviors) or behaviors == [] do
    {:error, "Invliad transaction behaviors"}
  end

  defp do_request("TransferTx", [%TxBehavior{} = beh], robert, user_addr) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        []

      # When robert only demands token from the user.
      Util.empty?(beh.asset) ->
        sender = %{address: user_addr, token: beh.token, asset: beh.asset}
        receiver = %{address: robert.address, token: nil, asset: nil}

        "TransferTx"
        |> Helper.get_transaction_to_sign(sender, receiver)
        |> Helper.require_signature(user_addr)

      # When robert demands asset from the user.
      true ->
        Helper.require_asset(beh.asset)
    end
  end

  defp do_request("ExchangeTx", behs, robert, user_addr) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(behs, fn beh -> beh.behavior == "demand" end)

    cond do
      # When robert does not demand asset from the user.
      Util.empty?(demand.asset) ->
        sender = %{address: user_addr, token: demand.token, asset: nil}
        offer_asset = Helper.gen_asset(robert, user_addr, offer.asset)
        receiver = %{address: robert.address, token: offer.token, asset: offer_asset}

        "ExchangeTx"
        |> Helper.get_transaction_to_sign(sender, receiver)
        |> Helper.require_signature(user_addr)

      # When robert demands asset from the user.
      true ->
        Helper.require_asset(demand.asset)
    end
  end

  defp do_request("UpdateAssetTx", [%TxBehavior{} = beh], _, _),
    do: Helper.require_asset(beh.asset)

  defp do_request("ActivateAssetTx", [%TxBehavior{} = beh], _, _),
    do: Helper.require_asset(beh.asset)

  defp do_request("ProofOfHolding", [%TxBehavior{} = beh], _, _) do
    hold_account = Helper.require_account(beh.token)
    hold_asset = Helper.require_asset(beh.asset)
    hold_account ++ hold_asset
  end

  defp do_response("TransferTx", [%TxBehavior{} = beh], claims, robert, user_addr) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" -> Transfer.response_offer(robert, user_addr, beh)
      # When robert only demands token from the user.
      Util.empty?(beh.asset) -> Transfer.response_demand_token(claims)
      # When robert demands asset from the user.
      true -> Transfer.response_demand_asset(robert, user_addr, beh, claims)
    end
  end

  defp do_response("ExchangeTx", behs, claims, robert, user_addr) do
    offer = Enum.find(behs, %{token: nil, asset: nil}, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(behs, fn beh -> beh.behavior == "demand" end)

    cond do
      # When robert only offers something to the user.
      demand == nil -> Exchange.response_offer(robert, user_addr, offer)
      # When robert only demands token from the user.
      Util.empty?(demand.asset) -> Exchange.response_demand_token(robert, claims)
      # When robert demands asset from the user.
      true -> Exchange.response_demand_asset(robert, user_addr, demand, offer, claims)
    end
  end

  defp do_response("UpdateAssetTx", [%TxBehavior{} = beh], claims, robert, user_addr),
    do: Update.response_update(robert, user_addr, beh, claims)

  defp reply({:error, error}, conn, _) do
    json(conn, %{error: error})
  end

  defp reply({:ok, response}, conn, _) do
    json(conn, response)
  end

  defp reply(claims, conn, tx_id) do
    app_state = AppState.get()

    extra = %{
      url: Util.get_callback() <> "transaction/#{tx_id}",
      requestedClaims: claims,
      appInfo: app_state.info
    }

    response = %{
      appPk: app_state.pk |> Multibase.encode!(:base58_btc),
      authInfo: AbtDid.Signer.gen_and_sign(app_state.did, app_state.sk, extra)
    }

    json(conn, response)
  end
end
