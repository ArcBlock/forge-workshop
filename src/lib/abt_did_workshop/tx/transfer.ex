defmodule AbtDidWorkshop.Tx.Transfer do
  alias AbtDidWorkshop.Tx.Helper

  def response_offer(robert, user_addr, beh) do
    asset = Helper.gen_asset(robert, user_addr, beh.asset)
    sender = %{address: robert.address, token: beh.token, asset: asset}
    receiver = %{address: user_addr, token: nil, asset: nil}

    "TransferTx"
    |> Helper.get_transaction_to_sign(sender, receiver)
    |> Helper.sign_tx(robert)
    |> Helper.send_tx()
  end

  def response_demand_token(claims) do
    f_sig = Helper.extract_sig()

    case Helper.get_claims([f_sig], claims) do
      false -> {:error, "Insufficient data to continue."}
      [c] -> c["origin"] |> Helper.assemble_sig(c["sig"]) |> Helper.send_tx()
    end
  end

  def response_demand_asset(robert, user_addr, beh, claims) do
    f_sig = Helper.extract_sig()

    case Helper.get_claims([f_sig], claims) do
      [c] ->
        c["origin"] |> Helper.assemble_sig(c["sig"]) |> Helper.send_tx()

      false ->
        f_asset = Helper.extract_asset()

        case Helper.get_claims([f_asset], claims) do
          [c] ->
            case Helper.validate_asset(beh.asset, c["did"], user_addr) do
              :ok -> do_response_demand_asset(robert, user_addr, beh, c["did"])
              {:error, reason} -> {:error, reason}
            end

          false ->
            {:error, "Insufficient data to continue."}
        end
    end
  end

  defp do_response_demand_asset(robert, user_addr, beh, asset) do
    sender = %{address: user_addr, token: beh.token, asset: asset}
    receiver = %{address: robert.address, token: nil, asset: nil}

    "TransferTx"
    |> Helper.get_transaction_to_sign(sender, receiver)
    |> Helper.require_signature(user_addr)
  end
end
