defmodule ForgeWorkshop.ClaimUtil do
  alias ForgeWorkshop.{Util, TxUtil}
  alias ForgeAbi.{Multisig, Transaction}
  alias Hyjal.Claims.{Asset, Signature}

  def find_signature_claim(claims) do
    Enum.find(claims, fn
      %Signature{sig: sig, origin: origin} -> sig != "" and origin != ""
      _ -> false
    end)
  end

  def find_asset_claim(claims) do
    Enum.find(claims, fn
      %Asset{asset: asset} -> asset != ""
      _ -> false
    end)
  end

  def gen_signature_claim(conn, desc) do
    conn.assigns.tx
    |> TxUtil.prepare_transaction(conn)
    |> do_gen_signature_claim(desc)
  end

  # For ExchangeTx, ConsumeAssetTx
  def gen_multi_sig_claim(conn, desc) do
    robert = conn.assigns.robert
    user = conn.assigns.auth_principal
    asset = Map.get(conn.assigns, :asset)

    conn.assigns.tx
    |> TxUtil.prepare_transaction(conn)
    |> TxUtil.sign_tx(robert)
    |> do_gen_multi_sig_claim(user, desc, asset)
  end

  def gen_asset_claim(description) do
    %Asset{
      description: description
    }
  end

  defp do_gen_signature_claim(%Transaction{} = transaction, description) do
    transaction_bin = Transaction.encode(transaction)
    did_type = AbtDid.get_did_type(transaction.from)
    digest = Util.hash(did_type.hash_type, transaction_bin)

    %Signature{
      description: description,
      type_url: "fg:t:transaction",
      method: did_type.hash_type,
      origin: transaction_bin,
      digest: digest
    }
  end

  defp do_gen_multi_sig_claim(%Transaction{} = transaction, user, description, asset)
       when is_binary(asset) or is_nil(asset) do
    msig =
      case transaction.itx.type_url do
        "fg:t:consume_asset" ->
          Multisig.new(
            signer: user.address,
            pk: user.pk,
            data: ForgeAbi.encode_any!(asset, "fg:x:address")
          )

        _ ->
          Multisig.new(signer: user.address, pk: user.pk)
      end

    do_gen_multi_sig_claim(transaction, user, description, msig)
  end

  defp do_gen_multi_sig_claim(%Transaction{} = transaction, user, description, %Multisig{} = msig) do
    transaction1 = %{transaction | signatures: [msig | transaction.signatures]}
    transaction_bin = Transaction.encode(transaction1)
    did_type = AbtDid.get_did_type(user.address)
    digest = Util.hash(did_type.hash_type, transaction_bin)

    %Signature{
      description: description,
      type_url: "fg:t:transaction",
      method: did_type.hash_type,
      origin: Multibase.encode!(transaction_bin, :base58_btc),
      digest: Multibase.encode!(digest, :base58_btc)
    }
  end
end
