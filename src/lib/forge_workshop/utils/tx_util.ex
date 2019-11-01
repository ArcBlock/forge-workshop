defmodule ForgeWorkshop.TxUtil do
  @moduledoc false

  alias ForgeWorkshop.AssetUtil

  alias ForgeAbi.{
    ConsumeAssetTx,
    DepositTetherTx,
    ExchangeInfo,
    ExchangeTx,
    ExchangeTetherTx,
    Multisig,
    PokeTx,
    TetherExchangeInfo,
    Transaction,
    TransferTx,
    UpdateAssetTx
  }

  require Logger

  @one_week 604_800
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

  def get_locktime(deposit) do
    itx = ForgeAbi.decode_any!(deposit.itx)
    itx.locktime
  end

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

  # for TransferTx, UpdateAssetTx, PokeTx
  def require_signature(conn, desc) do
    conn.assigns.tx
    |> prepare_transaction(conn)
    |> do_require_signature(desc)
  end

  # For ExchangeTx, ConsumeAssetTx
  def require_multi_sig(conn, desc) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    asset = Map.get(conn.assigns, :asset)

    conn.assigns.tx
    |> prepare_transaction(conn)
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

  def require_tether(description, token) do
    [
      %{
        meta: %{
          description: description
        },
        type: "deposit",
        target: token,
        deposit: ""
      }
    ]
  end

  def require_deposit_value(description) do
    [
      %{
        meta: %{
          description: description
        },
        type: "token",
        value: ""
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

  def robert_offer(robert, user, token, title) do
    offer_asset = gen_asset(robert, user.address, title)
    sender = Map.merge(robert, %{token: token, asset: offer_asset})

    "TransferTx"
    |> get_transaction_to_sign(sender, user)
    |> sign_tx(robert)
    |> send_tx()
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

  defp do_require_multi_sig(tx, user, description, asset)
       when is_binary(asset) or is_nil(asset) do
    msig =
      case tx.itx.type_url do
        "fg:t:consume_asset" ->
          Multisig.new(
            signer: user.address,
            pk: user.pk,
            data: ForgeAbi.encode_any!(asset, "fg:x:address")
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
  def prepare_transaction(%{tx_type: "PokeTx"}, conn) do
    user = conn.assigns.auth_principal

    "PokeTx"
    |> get_transaction_to_sign(user, nil)
    |> Map.put(:nonce, 0)
  end

  # User is always the sender.
  def prepare_transaction(%{tx_type: "TransferTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    asset = Map.get(conn.assigns, :asset)

    [beh] = tx.tx_behaviors
    sender = %{address: user.address, pk: user.pk, token: beh.token, asset: asset}
    receiver = %{address: robert.address}
    get_transaction_to_sign("TransferTx", sender, receiver)
  end

  # Robert is the sender, always requires multi sig from user
  def prepare_transaction(%{tx_type: "ExchangeTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    asset = Map.get(conn.assigns, :asset)

    offer = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "demand" end)

    offer_asset = gen_asset(robert, user.address, offer.asset)
    sender = %{address: robert.address, pk: robert.pk, token: offer.token, asset: offer_asset}
    receiver = %{address: user.address, pk: user.pk, token: demand.token, asset: asset}

    get_transaction_to_sign("ExchangeTx", sender, receiver)
  end

  # Robert is the sender, always requires multi sig from user
  def prepare_transaction(%{tx_type: "ExchangeTetherTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    deposit = conn.assigns.deposit

    offer = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "offer" end)

    offer_asset = gen_asset(robert, user.address, offer.asset)
    sender = %{address: robert.address, pk: robert.pk, token: offer.token, asset: offer_asset}
    receiver = %{address: user.address, pk: user.pk, deposit: deposit}

    get_transaction_to_sign("ExchangeTetherTx", sender, receiver)
  end

  # User is always the sender.
  def prepare_transaction(%{tx_type: "UpdateAssetTx"} = tx, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    asset = Map.get(conn.assigns, :asset)

    update = Enum.find(tx.tx_behaviors, fn beh -> beh.behavior == "update" end)
    sender = %{address: user.address, pk: user.pk, asset: asset}
    receiver = %{address: robert.address, sk: robert.sk, function: update.function}
    get_transaction_to_sign("UpdateAssetTx", sender, receiver)
  end

  # Robert is the sender, requires multi sig from user
  def prepare_transaction(%{tx_type: "ConsumeAssetTx"}, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.user

    get_transaction_to_sign("ConsumeAssetTx", robert, user)
  end

  def prepare_transaction(%{tx_type: "DepositTetherTx"}, conn) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    value = Map.get(conn.assigns, :deposit_value)
    custodian = conn.assigns.custodian

    receiver =
      custodian
      |> Map.put(:withdrawer, robert.address)
      |> Map.put(:deposit_value, value)

    get_transaction_to_sign("DepositTetherTx", user, receiver, "remote")
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

  defp get_itx_to_sign("DepositTetherTx", _sender, receiver) do
    block_time = ForgeSdk.get_chain_info("remote").block_time

    args = [
      value: to_tba(receiver.deposit_value),
      commission: to_tba(receiver.deposit_value * receiver.commission / 100),
      charge: to_tba(receiver.deposit_value * receiver.charge / 100),
      target: ForgeSdk.get_chain_info().network,
      withdrawer: receiver.withdrawer,
      locktime: %{block_time | seconds: block_time.seconds + @one_week}
    ]

    itx = apply(DepositTetherTx, :new, [args])
    ForgeAbi.encode_any!(itx, "fg:t:deposit_tether")
  end

  defp get_itx_to_sign("ExchangeTetherTx", sender, receiver) do
    s =
      apply(ExchangeInfo, :new, [[assets: to_assets(sender.asset), value: to_tba(sender.token)]])

    locktime = get_locktime(receiver.deposit)
    expired_at = %{locktime | seconds: locktime.seconds - 7200}

    r = apply(TetherExchangeInfo, :new, [[deposit: receiver.deposit, value: to_tba(nil)]])

    args = [receiver: r, sender: s, to: receiver.address, expired_at: expired_at]
    itx = apply(ExchangeTetherTx, :new, [args])

    ForgeAbi.encode_any!(itx, "fg:t:exchange_tether")
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
