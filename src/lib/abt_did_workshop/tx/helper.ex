defmodule AbtDidWorkshop.Tx.Helper do
  @moduledoc false

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

  def tba, do: ForgeAbi.one_token()

  def hash(:keccak, data), do: Mcrypto.hash(%Mcrypto.Hasher.Keccak{}, data)
  def hash(:sha3, data), do: Mcrypto.hash(%Mcrypto.Hasher.Sha3{}, data)

  def extract_sig do
    fn claim -> not Util.empty?(claim["sig"]) and not Util.empty?(claim["origin"]) end
  end

  def extract_asset do
    fn claim ->
      claim["did_type"] == "asset" and not Util.empty?(claim["did"])
    end
  end

  def validate_asset(nil, _, _), do: :ok

  def validate_asset(title, asset_address, owner_address) do
    case ForgeSdk.get_asset_state(address: asset_address) do
      nil ->
        {:error, "Could not find asset."}

      {:error, _} ->
        {:error, "Could not find asset."}

      state ->
        if Map.get(state, :owner) != owner_address do
          {:error, "The asset does not belong to the account."}
        else
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
  end

  def get_claims(expected, actual) when is_list(expected) do
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

  def get_claims(expected, actual) do
    get_claims([expected], actual)
  end

  def sign_tx(tx, wallet) do
    tx_data = Transaction.encode(tx)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, tx_data)
    %{tx | signature: sig}
  end

  def require_signature(tx, address, description) do
    tx_data = Transaction.encode(tx)
    did_type = AbtDid.get_did_type(address)
    data = hash(did_type.hash_type, tx_data)

    [
      %{
        type: "signature",
        meta: %{
          description: "#{description}\nPlease sign this transaction.",
          typeUrl: "fg:t:transaction"
        },
        data: Multibase.encode!(data, :base58_btc),
        origin: Multibase.encode!(tx_data, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]
  end

  def assemble_sig(tx_str, sig_str) do
    tx = tx_str |> Multibase.decode!() |> Transaction.decode()
    sig = Multibase.decode!(sig_str)
    %{tx | signature: sig}
  end

  def multi_sign(tx, wallet) do
    msig = ForgeAbi.Multisig.new(signer: wallet.address)
    tx1 = %{tx | signatures: [msig | tx.signatures]}
    data = ForgeAbi.Transaction.encode(tx1)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, data)
    %{tx | signatures: [%{msig | signature: sig} | tx.signatures]}
  end

  def require_multi_sig(tx, address, asset, description) do
    msig = ForgeAbi.Multisig.new(signer: address, data: ForgeAbi.encode_any!(:address, asset))
    tx1 = %{tx | signatures: [msig | tx.signatures]}
    tx_data = Transaction.encode(tx1)
    did_type = AbtDid.get_did_type(address)
    data = hash(did_type.hash_type, tx_data)

    [
      %{
        type: "signature",
        meta: %{
          description: "#{description}\nPlease sign this transaction.",
          typeUrl: "fg:t:transaction"
        },
        data: Multibase.encode!(data, :base58_btc),
        origin: Multibase.encode!(tx_data, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]
  end

  def assemble_multi_sig(tx_str, sig_str) do
    tx = tx_str |> Multibase.decode!() |> Transaction.decode()
    sig = Multibase.decode!(sig_str)
    [msig | rest] = tx.signatures
    msig = %{msig | signature: sig}
    %{tx | signatures: [msig | rest]}
  end

  def require_asset(_, nil), do: []
  def require_asset(_, ""), do: []

  def require_asset(description, asset_title) do
    [
      %{
        meta: %{
          description: "#{description}\nPlease provide asset: #{asset_title}."
        },
        type: "did",
        did_type: "asset",
        target: "#{asset_title}",
        did: ""
      }
    ]
  end

  def require_account(description) do
    [
      %{
        meta: %{
          description: "#{description}\nPlease provide an account."
        },
        type: "did",
        did_type: "account",
        did: ""
      }
    ]
  end

  def require_account(_, nil), do: []
  def require_account(_, 0), do: []

  def require_account(description, token) do
    [
      %{
        meta: %{
          description: "#{description}\nPlease provide an account with at least #{token} TBA."
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

  def send_tx(tx) do
    case ForgeSdk.send_tx(tx: tx) do
      {:error, reason} -> {:error, reason}
      hash -> {:ok, %{hash: hash}}
    end
  end

  # The sender, receiver is a map with three keys:
  # sender.address
  # sender.asset -- Assets that sender should provide
  # sender.token -- Token that sender should provide.
  # receiver could have one more key `function`
  def get_transaction_to_sign(tx_type, sender, receiver, sign? \\ false) do
    itx = get_itx_to_sign(tx_type, sender, receiver)

    tx =
      Transaction.new(
        chain_id: ForgeSdk.get_chain_info().network,
        from: sender.address,
        itx: itx,
        nonce: ForgeSdk.get_nonce(sender.address) + 1
      )

    case sign? do
      false -> tx
      true -> sign_tx(tx, sender.wallet)
    end
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

  defp get_itx_to_sign("ConsumeAssetTx", sender, _receiver) do
    itx = ForgeAbi.ConsumeAssetTx.new(issuer: sender.address)
    ForgeAbi.encode_any!(:consume_asset, itx)
  end

  defp to_tba(nil), do: nil

  defp to_tba(token) do
    ForgeAbi.token_to_arc(token)
  end

  defp to_assets(nil), do: []
  defp to_assets(asset), do: [asset]
end
