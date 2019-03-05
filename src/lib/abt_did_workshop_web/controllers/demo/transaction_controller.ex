defmodule AbtDidWorkshopWeb.TransactionController do
  @moduledoc """
  Executes transactions.
  """

  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{
    AppState,
    AssetUtil,
    Plugs.VerifySig,
    Tables.TxTable,
    TransactionHelper,
    TxBehavior,
    Util,
    WalletUtil
  }

  alias AbtDidWorkshopWeb.TransactionHelper

  alias ForgeAbi.Transaction

  plug(VerifySig when action in [:response])

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

  def response(conn, %{"id" => id}) do
    tx_id = String.to_integer(id)
    user_addr = conn.assigns.did
    claims = conn.assigns.claims
    {robert, _} = WalletUtil.init_robert()

    case TxTable.get(tx_id) do
      nil ->
        json(conn, %{error: "Cannot find transaction."})

      tx ->
        tx.tx_type
        |> do_response(tx.tx_behaviors, claims, robert, user_addr)
        |> reply(conn, tx_id)
    end
  end

  defp do_request(_, behaviors, _, _) when is_nil(behaviors) or behaviors == [] do
    %{error: "Invliad transaction behaviors"}
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
        |> TransactionHelper.get_transaction_to_sign(sender, receiver)
        |> require_signature(user_addr)

      # When robert demands asset from the user.
      true ->
        require_asset(beh.asset)
    end
  end

  defp do_request("ExchangeTx", behaviors, robert, user_addr) do
    offer = Enum.find(behaviors, %{token: nil, asset: nil}, fn beh -> beh.behavior == "offer" end)
    demand = Enum.find(behaviors, fn beh -> beh.behavior == "demand" end)

    cond do
      # When robert only offers something to the user.
      demand == nil ->
        []

      # When robert only demands token from the user.
      Util.empty?(demand.asset) ->
        sender = %{address: user_addr, token: demand.token, asset: nil}
        receiver = %{address: robert.address, token: offer.token, assets: offer.asset}

        "ExchangeTx"
        |> TransactionHelper.get_transaction_to_sign(sender, receiver)
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

  defp do_response("TransferTx", [%TxBehavior{} = beh], claims, robert, user_addr) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        asset = gen_asset(robert, user_addr, beh.asset)
        sender = %{address: robert.address, token: beh.token, asset: asset}
        receiver = %{address: user_addr, token: nil, asset: nil}

        "TransferTx"
        |> TransactionHelper.get_transaction_to_sign(sender, receiver)
        |> sign_tx(robert)
        |> send_tx()

      # When robert only demands token from the user.
      Util.empty?(beh.asset) ->
        f = fn claim -> not Util.empty?(claim["sig"]) and not Util.empty?(claim["origin"]) end

        case TransactionHelper.match?([f], claims) do
          false -> %{error: "Need transaction and it's signature."}
          [c] -> c["origin"] |> assemble_tx(c["sig"]) |> send_tx()
        end

      # When robert demands asset from the user.
      true ->
        f_sig = fn claim -> not Util.empty?(claim["sig"]) and not Util.empty?(claim["origin"]) end

        case TransactionHelper.match?([f_sig], claims) do
          [c] ->
            c["origin"] |> assemble_tx(c["sig"]) |> send_tx()

          false ->
            f_asset = fn claim ->
              claim["did_type"] == "asset" and not Util.empty?(claim["did"])
            end

            case TransactionHelper.match?([f_asset], claims) do
              [c] ->
                sender = %{address: user_addr, token: beh.token, asset: c["did"]}
                receiver = %{address: robert.address, token: nil, asset: nil}

                "TransferTx"
                |> TransactionHelper.get_transaction_to_sign(sender, receiver)
                |> require_signature(user_addr)

              false ->
                %{error: "Need transaction and it's signature."}
            end
        end
    end
  end

  defp require_signature(tx, address) do
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

  defp gen_asset(_from, _to, nil), do: nil
  defp gen_asset(_from, _to, ""), do: nil

  defp gen_asset(from, to, title) do
    case AssetUtil.init_cert(from, to, title) do
      {:error, reason} -> raise "Failed to create asset. Error: #{inspect(reason)}"
      {_, asset_address} -> asset_address
    end
  end

  defp sign_tx(tx, wallet) do
    tx_data = Transaction.encode(tx)
    sig = ForgeSdk.Wallet.Util.sign!(wallet, tx_data)
    %{tx | signature: sig}
  end

  defp send_tx(tx) do
    case ForgeSdk.send_tx(tx: tx) do
      {:error, reason} -> %{error: reason}
      hash -> {:ok, hash}
    end
  end

  defp assemble_tx(tx_str, sig_str) do
    tx = tx_str |> Multibase.decode!() |> Transaction.decode()
    sig = Multibase.decode!(sig_str)
    %{tx | signature: sig}
  end

  defp reply(%{error: error}, conn, _) do
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
