defmodule AbtDidWorkshop.Tx.Consume do
  alias AbtDidWorkshop.Tx.Helper

  def response_consume(robert, user_addr, beh, claims) do
    f_sig = Helper.extract_sig()

    case Helper.get_claims([f_sig], claims) do
      [c] ->
        c["origin"]
        |> Helper.assemble_multi_sig(c["sig"])
        |> Helper.send_tx()

      false ->
        f_asset = Helper.extract_asset()

        case Helper.get_claims([f_asset], claims) do
          [c] ->
            case Helper.validate_asset(beh.asset, c["did"], user_addr) do
              :ok -> do_response_consume(robert, user_addr, c["did"])
              {:error, reason} -> {:error, reason}
            end

          false ->
            {:error, "Insufficient data to continue."}
        end
    end
  end

  defp do_response_consume(robert, user_addr, asset) do
    sender = %{address: robert.address, wallet: robert}
    receiver = %{address: user_addr}

    "ConsumeAssetTx"
    |> Helper.get_transaction_to_sign(sender, receiver, true)
    |> Helper.require_multi_sig(user_addr, asset)
  end
end
