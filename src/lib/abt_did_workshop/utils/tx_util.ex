defmodule AbtDidWorkshop.TxUtil do
  @moduledoc false

  alias AbtDidWorkshop.AssetUtil

  alias ForgeAbi.{
    ConsumeAssetTx,
    ExchangeInfo,
    ExchangeTx,
    Multisig,
    Transaction,
    TransferTx,
    UpdateAssetTx
  }

  require Logger

  def hash(:keccak, data), do: Mcrypto.hash(%Mcrypto.Hasher.Keccak{}, data)
  def hash(:sha3, data), do: Mcrypto.hash(%Mcrypto.Hasher.Sha3{}, data)

  def assemble_sig(tx_str, sig_str) do
    tx = tx_str |> Multibase.decode!() |> Transaction.decode()
    sig = Multibase.decode!(sig_str)
    %{tx | signature: sig}
  end

  def assemble_multi_sig(tx_str, sig_str) do
    tx = tx_str |> Multibase.decode!() |> Transaction.decode()
    sig = Multibase.decode!(sig_str)
    [msig | rest] = tx.signatures
    msig = %{msig | signature: sig}
    %{tx | signatures: [msig | rest]}
  end

  # for TransferTx, UpdateTx, PokeTx
  def require_signature(conn, desc) do
    tx = conn.assigns.tx
    robert = conn.assigns.robert
    user = conn.assigns.user
    asset = Map.get(conn.assigns, :asset)

    tx
    |> prepare_transaction(robert, user, asset)
    |> do_require_signature(desc)
  end

  # For ExchangeTx, ConsumeTx
  def require_multi_sig(conn, desc) do
    tx = conn.assigns.tx
    robert = conn.assigns.robert
    user = conn.assigns.user
    asset = Map.get(conn.assigns, :asset)

    tx
    |> prepare_transaction(robert, user, asset)
    |> sign_tx(robert)
    |> do_require_multi_sig(user, desc, asset)
  end

  def require_asset(_, nil), do: []
  def require_asset(_, ""), do: []

  def require_asset(description, asset_title) do
    [
      %{
        meta: %{
          description: description
        },
        type: "did",
        did_type: "asset",
        target: "#{asset_title}",
        did: ""
      }
    ]
  end

  def require_account(description, 0) do
    [
      %{
        meta: %{
          description: description
        },
        type: "did",
        did_type: "account",
        did: ""
      }
    ]
  end

  def require_account(description, token) do
    [
      %{
        meta: %{
          description: description
        },
        type: "did",
        did_type: "account",
        target: token,
        did: ""
      }
    ]
  end

  def gen_asset(_from, _to, nil), do: nil
  def gen_asset(_from, _to, ""), do: nil

  def gen_asset(from, to, title) do
    case AssetUtil.init_cert(from, to, title) do
      {:error, reason} ->
        Logger.error("Failed to create asset. Error: #{inspect(reason)}")
        raise "Failed to create asset. Error: #{inspect(reason)}"

      {_, asset_address} ->
        asset_address
    end
  end

  def sign_tx(tx, wallet) do
    tx_data = Transaction.encode(tx)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, tx_data)
    %{tx | signature: sig}
  end

  def send_tx(tx) do
    case ForgeSdk.send_tx(tx: tx) do
      {:error, reason} ->
        Logger.error(
          "Failed to send tx. Reason: #{inspect(reason)}. Transaction: #{
            inspect(tx, limit: :infinity)
          }"
        )

        {:error, reason}

      hash ->
        {:ok, %{hash: hash, tx: tx |> Transaction.encode() |> Multibase.encode!(:base58_btc)}}
    end
  end

  def multi_sign(tx, wallet) do
    msig = ForgeAbi.Multisig.new(signer: wallet.address, pk: wallet.pk)
    tx1 = %{tx | signatures: [msig | tx.signatures]}
    data = ForgeAbi.Transaction.encode(tx1)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, data)
    %{tx | signatures: [%{msig | signature: sig} | tx.signatures]}
  end

  def get_transaction_to_sign(tx_type, sender, receiver) do
    itx = get_itx_to_sign(tx_type, sender, receiver)

    Transaction.new(
      chain_id: ForgeSdk.get_chain_info().network,
      from: sender.address,
      pk: sender.pk,
      itx: itx,
      nonce: :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.to_integer(16)
    )
  end

  defp do_require_signature(tx, description) do
    tx_data = Transaction.encode(tx)
    did_type = AbtDid.get_did_type(tx.from)
    data = hash(did_type.hash_type, tx_data)

    [
      %{
        type: "signature",
        meta: %{
          description: description,
          typeUrl: "fg:t:transaction"
        },
        data: Multibase.encode!(data, :base58_btc),
        origin: Multibase.encode!(tx_data, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]
  end

  defp do_require_multi_sig(tx, user, description, asset) when is_binary(asset) do
    msig =
      case tx.itx.__struct__ do
        ConsumeAssetTx ->
          Multisig.new(
            signer: user.address,
            pk: user.pk,
            data: ForgeAbi.encode_any!(:address, asset)
          )

        _ ->
          Multisig.new(signer: user.address, pk: user.pk)
      end

    do_require_multi_sig(tx, user, description, msig)
  end

  defp do_require_multi_sig(tx, user, description, %Multisig{} = msig) do
    tx1 = %{tx | signatures: [msig | tx.signatures]}
    tx_data = Transaction.encode(tx1)
    did_type = AbtDid.get_did_type(user.address)
    data = hash(did_type.hash_type, tx_data)

    [
      %{
        type: "signature",
        meta: %{
          description: description,
          typeUrl: "fg:t:transaction"
        },
        data: Multibase.encode!(data, :base58_btc),
        origin: Multibase.encode!(tx_data, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]
  end

  # User is always the sender.
  defp prepare_transaction(%{tx_type: "PokeTx"}, _, user, _) do
    "PokeTx"
    |> get_transaction_to_sign(user, nil)
    |> Map.put(:nonce, 0)
  end

  # User is always the sender.
  defp prepare_transaction(%{tx_type: "TransferTx"} = tx, robert, user, asset) do
    [beh] = tx.tx_behaviors
    sender = %{address: user.address, pk: user.pk, token: beh.token, asset: asset}
    receiver = %{address: robert.address}
    get_transaction_to_sign("TransferTx", sender, receiver)
  end

  # Robert is the sender, always requires multi sig from user
  defp prepare_transaction(%{tx_type: "ExchangeTx"} = tx, robert, user, asset) do
    offer = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "demand" end)

    offer_asset = gen_asset(robert, user.address, offer.asset)
    sender = %{address: robert.address, pk: robert.pk, token: offer.token, asset: offer_asset}
    receiver = %{address: user.address, pk: user.pk, token: demand.token, asset: asset}

    get_transaction_to_sign("ExchangeTx", sender, receiver)
  end

  # User is always the sender.
  defp prepare_transaction(%{tx_type: "UpdateTx"} = tx, robert, user, asset) do
    update = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "update" end)
    sender = %{address: user.address, pk: user.pk, asset: asset}
    receiver = %{address: robert.address, sk: robert.sk, function: update.function}
    get_transaction_to_sign("UpdateAssetTx", sender, receiver)
  end

  # Robert is the sender, requires multi sig from user
  defp prepare_transaction(%{tx_type: "ConsumeAssetTx"}, robert, user, _) do
    get_transaction_to_sign("ConsumeAssetTx", robert, user)
  end

  defp get_itx_to_sign("PokeTx", _, _) do
    state = ForgeSdk.get_forge_state()

    itx =
      ForgeAbi.PokeTx.new(
        address: state.poke_config.address,
        date: DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()
      )

    ForgeAbi.encode_any!(:poke, itx)
  end

  defp get_itx_to_sign("TransferTx", sender, receiver) do
    itx =
      TransferTx.new(
        assets: to_assets(sender.asset),
        to: receiver.address,
        value: to_tba(sender.token)
      )

    ForgeAbi.encode_any!(:transfer, itx)
  end

  defp get_itx_to_sign("ExchangeTx", sender, receiver) do
    s = ExchangeInfo.new(assets: to_assets(sender.asset), value: to_tba(sender.token))
    r = ExchangeInfo.new(assets: to_assets(receiver.asset), value: to_tba(receiver.token))
    itx = ExchangeTx.new(receiver: r, sender: s, to: receiver.address)
    ForgeAbi.encode_any!(:exchange, itx)
  end

  defp get_itx_to_sign("UpdateAssetTx", sender, receiver) do
    {_, cert} =
      case ForgeSdk.get_asset_state(address: sender.asset) do
        nil -> raise "Could not find asset #{sender.asset}."
        state -> ForgeAbi.decode_any(state.data)
      end

    {func, _} = Code.eval_string(receiver.function)
    new_content = func.(cert.content)
    new_cert = AssetUtil.gen_cert(receiver, sender.address, cert.title, new_content)

    itx =
      UpdateAssetTx.new(
        address: sender.asset,
        data: ForgeAbi.encode_any!(:workshop_asset, new_cert)
      )

    ForgeAbi.encode_any!(:update_asset, itx)
  end

  defp get_itx_to_sign("ConsumeAssetTx", sender, _receiver) do
    itx = ForgeAbi.ConsumeAssetTx.new(issuer: sender.address)
    ForgeAbi.encode_any!(:consume_asset, itx)
  end

  defp to_tba(nil), do: nil
  defp to_tba(token), do: ForgeAbi.token_to_unit(token)

  defp to_assets(nil), do: []
  defp to_assets(asset), do: [asset]
end
