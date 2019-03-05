defmodule AbtDidWorkshop.Tx.Helper do
  alias AbtDidWorkshop.{
    AssetUtil,
    Util
  }

  alias ForgeAbi.{
    ExchangeInfo,
    ExchangeTx,
    Transaction,
    TransferTx,
    UpdateAssetTx
  }

  @tba 1_000_000_000_000_000

  def extract_sig do
    fn claim -> not Util.empty?(claim["sig"]) and not Util.empty?(claim["origin"]) end
  end

  def extract_asset do
    fn claim ->
      claim["did_type"] == "asset" and not Util.empty?(claim["did"])
    end
  end

  def validate_asset(title, asset_address) do
    case ForgeSdk.get_asset_state(address: asset_address) do
      nil ->
        {:error, "Could not find asset."}

      state ->
        case ForgeAbi.decode_any(state.data) do
          {:certificate, cert} ->
            case cert.title do
              ^title -> :ok
              _ -> {:error, "Incorrect certificate title."}
            end

          _ ->
            {:error, "Invalid asset."}
        end
    end
  end

  # The sender, receiver is a map with three keys:
  # sender.address
  # sender.asset -- Assets that sender should provide
  # sender.token -- Token that sender should provide.
  # receiver could have one more key `function`
  def get_transaction_to_sign(tx_type, sender, receiver) do
    itx = get_itx_to_sign(tx_type, sender, receiver)

    Transaction.new(
      chain_id: "forge-local",
      from: sender.address,
      itx: itx,
      nonce: ForgeSdk.get_nonce(sender.address) + 1
    )
  end

  def get_claims(expected, actual) do
    found =
      expected
      |> Enum.map(fn func -> Enum.find(actual, fn claim -> func.(claim) end) end)
      |> Enum.reject(&is_nil/1)

    if length(found) == length(expected) do
      found
    else
      false
    end
  end

  def require_signature(tx, address) do
    tx_data = Transaction.encode(tx)
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

  def require_asset(nil), do: []
  def require_asset(""), do: []

  def require_asset(asset_title) do
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

  def require_account(nil), do: []
  def require_account(0), do: []

  def require_account(token) do
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

  def gen_asset(_from, _to, nil), do: nil
  def gen_asset(_from, _to, ""), do: nil

  def gen_asset(from, to, title) do
    case AssetUtil.init_cert(from, to, title) do
      {:error, reason} -> raise "Failed to create asset. Error: #{inspect(reason)}"
      {_, asset_address} -> asset_address
    end
  end

  def sign_tx(tx, wallet) do
    tx_data = Transaction.encode(tx)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, tx_data)
    %{tx | signature: sig}
  end

  def multi_sign(tx, wallet) do
    msig = ForgeAbi.Multisig.new(signer: wallet.address)
    tx1 = %{tx | signatures: [msig | tx.signatures]}
    data = ForgeAbi.Transaction.encode(tx1)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, data)
    %{tx | signatures: [%{msig | signature: sig} | tx.signatures]}
  end

  def send_tx(tx) do
    case ForgeSdk.send_tx(tx: tx) do
      {:error, reason} -> {:error, reason}
      hash -> {:ok, hash}
    end
  end

  def assemble_tx(tx_str, sig_str) do
    tx = tx_str |> Multibase.decode!() |> Transaction.decode()
    sig = Multibase.decode!(sig_str)
    %{tx | signature: sig}
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
        data: ForgeAbi.encode_any!(:certificate, new_cert)
      )

    ForgeAbi.encode_any!(:update_asset, itx)
  end

  # defp get_itx_to_sign("ActivateAssetTx", [beh], from, user_addr, [asset]) do
  # end

  defp to_tba(nil), do: nil

  defp to_tba(token) do
    ForgeAbi.Util.BigInt.biguint(token * @tba)
  end

  defp to_assets(nil), do: []
  defp to_assets(asset), do: [asset]

  defp do_hash(:keccak, data), do: Mcrypto.hash(%Mcrypto.Hasher.Keccak{}, data)
  defp do_hash(:sha3, data), do: Mcrypto.hash(%Mcrypto.Hasher.Sha3{}, data)
end
