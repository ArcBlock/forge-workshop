defmodule AbtDidWorkshopWeb.TransactionController do
  @moduledoc """
  Executes transactions.
  """

  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{
    Plugs.VerifySig,
    Tables.DemoTable,
    Tables.TxTable,
    Tx.Consume,
    Tx.Exchange,
    Tx.Helper,
    Tx.Poh,
    Tx.Transfer,
    Tx.Update,
    TxBehavior,
    Util,
    WalletUtil
  }

  require Logger

  plug(VerifySig when action in [:response])

  def request(conn, %{"id" => id, "userDid" => did} = params) do
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
  rescue
    e ->
      # Logger.error()
      reply({:error, Exception.message(e)}, conn, id)
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
  rescue
    e -> reply({:error, Exception.message(e)}, conn, id)
  end

  defp do_request(_, behaviors, _, _) when is_nil(behaviors) or behaviors == [] do
    {:error, "Invliad transaction behaviors"}
  end

  defp do_request("TransferTx", [%TxBehavior{} = beh], robert, user_addr) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        Helper.require_account(beh.description)

      # When robert only demands token from the user.
      Util.empty?(beh.asset) ->
        sender = %{address: user_addr, token: beh.token, asset: beh.asset}
        receiver = %{address: robert.address, token: nil, asset: nil}

        "TransferTx"
        |> Helper.get_transaction_to_sign(sender, receiver)
        |> Helper.require_signature(user_addr, beh.description)

      # When robert demands asset from the user.
      true ->
        Helper.require_asset(beh.description, beh.asset)
    end
  end

  defp do_request("ExchangeTx", behs, robert, user_addr) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(behs, fn beh -> beh.behavior == "demand" end)

    if Util.empty?(demand.asset) do
      # When robert does not demand asset from the user.
      sender = %{address: user_addr, token: demand.token, asset: nil}
      offer_asset = Helper.gen_asset(robert, user_addr, offer.asset)
      receiver = %{address: robert.address, token: offer.token, asset: offer_asset}

      "ExchangeTx"
      |> Helper.get_transaction_to_sign(sender, receiver)
      |> Helper.require_signature(user_addr, demand.description)

      # When robert demands asset from the user.
    else
      Helper.require_asset(demand.description, demand.asset)
    end
  end

  defp do_request("UpdateAssetTx", behaviors, _, _) do
    update = Enum.find(behaviors, fn beh -> beh.behavior == "update" end)
    Helper.require_asset(update.description, update.asset)
  end

  defp do_request("ConsumeAssetTx", behaviors, _, _) do
    consume = Enum.find(behaviors, fn beh -> beh.behavior == "consume" end)
    Helper.require_asset(consume.description, consume.asset)
  end

  defp do_request("ProofOfHolding", behaviors, _, _) do
    poh = Enum.find(behaviors, fn beh -> beh.behavior == "poh" end)
    hold_account = Helper.require_account(poh.description, poh.token)
    hold_asset = Helper.require_asset(poh.description, poh.asset)
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

  defp do_response("UpdateAssetTx", behs, claims, robert, user_addr) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)
    update = Enum.find(behs, fn beh -> beh.behavior == "update" end)

    robert
    |> Update.response_update(user_addr, update, claims)
    |> continue_offer(robert, user_addr, offer)
  end

  defp do_response("ConsumeAssetTx", behs, claims, robert, user_addr) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)
    consume = Enum.find(behs, fn beh -> beh.behavior == "consume" end)

    robert
    |> Consume.response_consume(user_addr, consume, claims)
    |> continue_offer(robert, user_addr, offer)
  end

  defp do_response("ProofOfHolding", behs, claims, robert, user_addr) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)
    poh = Enum.find(behs, fn beh -> beh.behavior == "poh" end)

    poh
    |> Poh.response_poh(claims, user_addr)
    |> continue_offer(robert, user_addr, offer)
  end

  defp continue_offer(result, _, _, nil), do: result

  defp continue_offer(result, robert, user_addr, offer) do
    case result do
      :ok ->
        Transfer.response_offer(robert, user_addr, offer)

      {:ok, hash1} ->
        async_offer(hash1, robert, user_addr, offer)
        {:ok, hash1}

      error ->
        error
    end
  end

  defp async_offer(hash, robert, user_addr, offer) do
    IO.inspect(binding(), label: "@@@")

    Task.async(fn ->
      tx = get_tx(hash)

      case tx.code do
        0 -> Transfer.response_offer(robert, user_addr, offer)
        _ -> {:ok, hash}
      end
    end)
  end

  defp get_tx(hash), do: get_tx(hash, 0)
  defp get_tx(_, 30_000), do: %{code: -1}

  defp get_tx(hash, wait) do
    case ForgeSdk.get_tx(hash: hash) do
      {:error, _} ->
        Process.sleep(1000)
        get_tx(hash, wait + 1000)

      tx ->
        tx
    end
  end

  defp reply({:error, error}, conn, _) do
    json(conn, %{error: error})
  end

  defp reply({:ok, response}, conn, _) do
    json(conn, %{response: response})
  end

  defp reply(:ok, conn, _) do
    json(conn, %{response: "ok"})
  end

  defp reply(claims, conn, tx_id) do
    demo = DemoTable.get_by_tx_id(tx_id)

    app_info =
      demo
      |> Map.take([:name, :subtitle, :description, :icon])
      |> Map.put(:chainId, ForgeSdk.get_chain_info().network)
      |> Map.put(:chainHost, "http://#{Util.get_ip()}:8210/api/playground")
      |> Map.put(:chainToken, "TBA")
      |> Map.put(:decimals, ForgeAbi.one_token() |> :math.log10() |> Kernel.trunc())

    extra = %{
      url: Util.get_callback() <> "transaction/#{tx_id}",
      requestedClaims: claims,
      appInfo: app_info
    }

    response = %{
      appPk: demo.pk,
      authInfo: AbtDid.Signer.gen_and_sign(demo.did, Multibase.decode!(demo.sk), extra)
    }

    json(conn, response)
  end
end
