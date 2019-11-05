defmodule ForgeWorkshop.TxUtil do
  @moduledoc false

  alias ForgeWorkshop.AssetUtil

  alias ForgeAbi.{
    ConsumeAssetTx,
    ExchangeInfo,
    ExchangeTx,
    PokeTx,
    Transaction,
    TransferTx,
    UpdateAssetTx
  }

  require Logger

  @hasher %Mcrypto.Hasher.Sha2{round: 1}

  def get_tx_hash(%Transaction{} = tx) do
    tx
    |> Transaction.encode()
    |> get_tx_hash()
  end

  def get_tx_hash(tx_bin) when is_binary(tx_bin) do
    @hasher
    |> Mcrypto.hash(tx_bin)
    |> Base.encode16()
  end

  def hash(:keccak, data), do: Mcrypto.hash(%Mcrypto.Hasher.Keccak{}, data)
  def hash(:sha3, data), do: Mcrypto.hash(%Mcrypto.Hasher.Sha3{}, data)

  def assemble_sig(tx_bin, sig_bin) do
    tx = Transaction.decode(tx_bin)
    %{tx | signature: sig_bin}
  end

  def assemble_multi_sig(tx_bin, sig_bin) do
    tx = Transaction.decode(tx_bin)
    [msig | rest] = tx.signatures
    msig = %{msig | signature: sig_bin}
    %{tx | signatures: [msig | rest]}
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
    local = ForgeSdk.get_chain_info().network

    chan =
      case tx.chain_id == local do
        true -> ""
        _ -> "remote"
      end

    case ForgeSdk.send_tx([tx: tx, commit: true], chan) do
      {:error, reason} ->
        Logger.warn(
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

  def get_transaction_to_sign(tx_type, sender, receiver, chan \\ "") do
    itx = get_itx_to_sign(tx_type, sender, receiver)

    Transaction.new(
      chain_id: ForgeSdk.get_chain_info(chan).network,
      from: sender.address,
      pk: sender.pk,
      itx: itx,
      nonce: :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.to_integer(16)
    )
  end

  def async_offer(_, _, _, nil), do: :ok

  def async_offer({:ok, %{hash: hash}}, robert, user, offer) do
    Task.async(fn ->
      Process.sleep(10_000)
      tx = ForgeSdk.get_tx(hash: hash)

      if tx != nil && tx.code == 0 do
        robert_offer(robert, user, offer.token, offer.asset)
      end
    end)
  end

  def async_offer(_, _, _, _), do: :ok

  def robert_offer(_, _, nil), do: :ok
  def robert_offer(robert, user, offer), do: robert_offer(robert, user, offer.token, offer.asset)

  def robert_offer(robert, user, token, title) do
    offer_asset = gen_asset(robert, user.address, title)
    sender = Map.merge(robert, %{token: token, asset: offer_asset})

    "TransferTx"
    |> get_transaction_to_sign(sender, user)
    |> sign_tx(robert)
    |> send_tx()
  end

  # User is always the sender.
  def prepare_transaction(%{tx_type: "PokeTx"}, conn) do
    user = conn.assigns.auth_principal

    "PokeTx"
    |> get_transaction_to_sign(user, nil)
    |> Map.put(:nonce, 0)
  end

  # User is always the sender.
  def prepare_transaction(%{tx_type: "TransferTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    asset = Map.get(conn.assigns, :asset)

    [beh] = tx.tx_behaviors
    sender = %{address: user.address, pk: user.pk, token: beh.token, asset: asset}
    receiver = %{address: robert.address}
    get_transaction_to_sign("TransferTx", sender, receiver)
  end

  # Robert is the sender, always requires multi sig from user
  def prepare_transaction(%{tx_type: "ExchangeTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    asset = Map.get(conn.assigns, :asset)

    offer = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "demand" end)

    offer_asset = gen_asset(robert, user.address, offer.asset)
    sender = %{address: robert.address, pk: robert.pk, token: offer.token, asset: offer_asset}
    receiver = %{address: user.address, pk: user.pk, token: demand.token, asset: asset}

    get_transaction_to_sign("ExchangeTx", sender, receiver)
  end

  # User is always the sender.
  def prepare_transaction(%{tx_type: "UpdateAssetTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    asset = Map.get(conn.assigns, :asset)

    update = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "update" end)
    sender = %{address: user.address, pk: user.pk, asset: asset}
    receiver = %{address: robert.address, sk: robert.sk, function: update.function}
    get_transaction_to_sign("UpdateAssetTx", sender, receiver)
  end

  # Robert is the sender, requires multi sig from user
  def prepare_transaction(%{tx_type: "ConsumeAssetTx"}, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal

    get_transaction_to_sign("ConsumeAssetTx", robert, user)
  end

  defp get_itx_to_sign("PokeTx", _, _) do
    %{address: address} =
      ForgeSdk.get_forge_state()
      |> Map.from_struct()
      |> get_in([:account_config, "token_holder"])

    itx =
      apply(PokeTx, :new, [
        [
          address: address,
          date: DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()
        ]
      ])

    ForgeAbi.encode_any!(itx, "fg:t:poke")
  end

  defp get_itx_to_sign("TransferTx", sender, receiver) do
    itx =
      apply(TransferTx, :new, [
        [
          assets: to_assets(sender.asset),
          to: receiver.address,
          value: to_tba(sender.token)
        ]
      ])

    ForgeAbi.encode_any!(itx, "fg:t:transfer")
  end

  defp get_itx_to_sign("ExchangeTx", sender, receiver) do
    s =
      apply(ExchangeInfo, :new, [[assets: to_assets(sender.asset), value: to_tba(sender.token)]])

    r =
      apply(ExchangeInfo, :new, [
        [assets: to_assets(receiver.asset), value: to_tba(receiver.token)]
      ])

    itx = apply(ExchangeTx, :new, [[receiver: r, sender: s, to: receiver.address]])
    ForgeAbi.encode_any!(itx, "fg:t:exchange")
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
      apply(UpdateAssetTx, :new, [
        [
          address: sender.asset,
          data: ForgeAbi.encode_any!(new_cert, "ws:x:workshop_asset")
        ]
      ])

    ForgeAbi.encode_any!(itx, "fg:t:update_asset")
  end

  defp get_itx_to_sign("ConsumeAssetTx", sender, _receiver) do
    itx = apply(ConsumeAssetTx, :new, [[issuer: sender.address]])
    ForgeAbi.encode_any!(itx, "fg:t:consume_asset")
  end

  defp to_tba(nil), do: ForgeAbi.token_to_unit(0)
  defp to_tba(token), do: ForgeAbi.token_to_unit(token)

  defp to_assets(nil), do: []
  defp to_assets(asset), do: [asset]
end
