defmodule AbtDidWorkshop.Tx.Update do
  alias AbtDidWorkshop.Tx.Helper

  def response_update(robert, user_addr, beh, claims) do
    f_sig = Helper.extract_sig()

    case Helper.get_claims([f_sig], claims) do
      [c] ->
        c["origin"] |> Helper.assemble_tx(c["sig"]) |> Helper.send_tx()

      false ->
        f_asset = Helper.extract_asset()

        case Helper.get_claims([f_asset], claims) do
          [c] ->
            case Helper.validate_asset(beh.asset, c["did"], user_addr) do
              :ok -> do_response_update(robert, user_addr, beh, c["did"])
              {:error, reason} -> {:error, reason}
            end

          false ->
            {:error, "Insufficient data to continue."}
        end
    end
  end

  defp do_response_update(robert, user_addr, beh, asset) do
    sender = %{address: user_addr, asset: asset}
    receiver = %{address: robert.address, sk: robert.sk, function: beh.function}

    "UpdateAssetTx"
    |> Helper.get_transaction_to_sign(sender, receiver)
    |> Helper.require_signature(user_addr)
  end
end
