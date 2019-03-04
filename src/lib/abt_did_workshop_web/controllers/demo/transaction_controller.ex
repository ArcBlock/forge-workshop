defmodule AbtDidWorkshopWeb.TransactionController do
  @moduledoc """
  Executes transactions.
  """

  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{
    AppState,
    AssetUtil,
    Certificate,
    Tables.TxTable,
    TxBehavior,
    Util,
    WalletUtil
  }

  @tba 1_000_000_000_000_000_000

  def request(conn, %{"id" => id, "userDid" => did}) do
    tx_id = String.to_integer(id)
    user_addr = Util.did_to_address(did)
    {robert, _} = WalletUtil.init_robert()

    case TxTable.get(tx_id) do
      nil ->
        json(conn, %{error: "Cannot find transaction."})

      tx ->
        tx.tx_type
        |> do_request(tx.tx_behaviors, robert, user_addr)
        |> reply(conn, tx_id)
    end
  end

  def response(conn, %{"id" => tx_id}) do
    json(conn, %{error: "response #{tx_id}"})
  end

  defp do_request(_, behaviors, _, _) when is_nil(behaviors) or behaviors == [] do
    %{error: "Invliad transaction behaviors"}
  end

  defp do_request("TransferTx", [%TxBehavior{} = beh], from, user_addr) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        []

      # When robert only demands token from the user.
      Util.empty?(beh.asset) ->
        "TransferTx"
        |> get_transaction_to_sign([beh], from, user_addr)
        |> require_signature(user_addr)

      # When robert demands asset from the user.
      true ->
        require_asset(beh.asset)
    end
  end

  defp do_request("ExchangeTx", behaviors, from, user_addr) do
    offer = Enum.find(behaviors, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(behaviors, fn beh -> beh.behavior == "demand" end)

    cond do
      # When robert only offers something to the user.
      demand == nil ->
        []

      # When robert only demands token from the user.
      Util.empty?(demand.asset) ->
        "ExchangeTx"
        |> get_transaction_to_sign([demand, offer], from, user_addr)
        |> require_signature(user_addr)

      # When robert demands asset from the user.
      true ->
        require_asset(demand.asset)
    end
  end

  defp do_request("UpdateAssetTx", [%TxBehavior{} = beh], _, _), do: require_asset(beh.asset)
  defp do_request("ActivateAssetTx", [%TxBehavior{} = beh], _, _), do: require_asset(beh.asset)

  defp do_request("ProofOfHolding", [%TxBehavior{} = beh], _, _) do
    hold_account =
      if Util.empty?(beh.token) do
        []
      else
        require_account(beh.token)
      end

    hold_asset =
      if Util.empty?(beh.asset) do
        []
      else
        require_asset(beh.asset)
      end

    hold_account ++ hold_asset
  end

  defp get_transaction_to_sign(tx_type, behaviors, from, user_addr, assets \\ []) do
    itx = get_itx_to_sign(tx_type, behaviors, from, user_addr, assets)

    ForgeAbi.Transaction.new(
      chain_id: "forge_local",
      from: user_addr,
      itx: itx,
      nonce: ForgeSdk.get_nonce(user_addr) + 1
    )
    |> ForgeAbi.Transaction.encode()
  end

  defp get_itx_to_sign("TransferTx", [beh], from, _user_addr, assets) do
    itx = ForgeAbi.TransferTx.new(assets: assets, to: from.address, value: to_tba(beh.token))
    ForgeAbi.encode_any!(:transfer, itx)
  end

  defp get_itx_to_sign("ExchangeTx", [demand, offer], from, user_addr, assets) do
    sender = ForgeAbi.ExchangeInfo.new(assets: assets, value: to_tba(demand.token))

    receiver =
      if offer == nil do
        ForgeAbi.ExchangeInfo.new()
      else
        certs = gen_assets(from, user_addr, offer.asset)
        ForgeAbi.ExchangeInfo.new(assets: certs, value: to_tba(offer.token))
      end

    itx = ForgeAbi.ExchangeTx.new(receiver: receiver, sender: sender, to: from.address)
    ForgeAbi.encode_any!(:exchange, itx)
  end

  defp get_itx_to_sign("UpdateAssetTx", [beh], from, user_addr, [asset]) do
    {_, cert} =
      case ForgeSdk.get_asset_state(address: asset) do
        nil -> raise "Could not find asset #{asset}."
        state -> ForgeAbi.decode_any(state.data)
      end

    {func, _} = Code.eval_string(beh.function)
    new_content = func.(cert.content)
    new_cert = AssetUtil.gen_cert(from, user_addr, cert.title, new_content)
    itx = ForgeAbi.UpdateAssetTx.new(address: asset, data: Certificate.encode(new_cert))
    ForgeAbi.encode_any!(:update_asset, itx)
  end

  # defp get_itx_to_sign("ActivateAssetTx", [beh], from, user_addr, [asset]) do
  # end

  defp require_signature(tx_data, address) do
    did_type = AbtDid.get_did_type(address)
    data = do_hash(did_type.hash_type, tx_data)

    [
      %{
        type: "signature",
        meta: %{
          description: "Please sign this transaction.",
          typeUrl: "fg:t:transaction"
        },
        data: Multibase.encode!(data, :base58_btc),
        origin: Multibase.encode!(tx_data, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]
  end

  defp require_asset(asset_title) do
    [
      %{
        meta: %{
          description: "Please provide asset: #{asset_title}."
        },
        type: "did",
        did_type: "asset",
        target: "#{asset_title}",
        did: ""
      }
    ]
  end

  defp require_account(token) do
    [
      %{
        meta: %{
          description: "Please provide an account with at least #{token} TBA."
        },
        type: "did",
        did_type: "account",
        target: token,
        did: ""
      }
    ]
  end

  defp gen_assets(_from, _to, nil), do: []
  defp gen_assets(_from, _to, ""), do: []

  defp gen_assets(from, to, title) do
    case AssetUtil.init_cert(from, to, title) do
      {:error, reason} -> raise "Failed to create asset. Error: #{inspect(reason)}"
      {_, asset_address} -> [asset_address]
    end
  end

  defp to_tba(nil), do: nil

  defp to_tba(token) do
    ForgeAbi.Util.BigInt.biguint(token * @tba)
  end

  defp reply(%{error: error}, conn, _) do
    json(conn, %{error: error})
  end

  defp reply(claims, conn, tx_id) do
    app_state = AppState.get()

    extra = %{
      url: Util.get_callback() <> "transaction/#{tx_id}",
      requestedClaims: claims,
      appInfo: app_state.info
    }

    # |> IO.inspect(label: "@@@")

    response = %{
      appPk: app_state.pk |> Multibase.encode!(:base58_btc),
      authInfo: AbtDid.Signer.gen_and_sign(app_state.did, app_state.sk, extra)
    }

    json(conn, response)
  end

  defp do_hash(:keccak, data), do: Mcrypto.hash(%Mcrypto.Hasher.Keccak{}, data)
  defp do_hash(:sha3, data), do: Mcrypto.hash(%Mcrypto.Hasher.Sha3{}, data)
end
