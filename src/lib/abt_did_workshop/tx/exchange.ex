defmodule AbtDidWorkshop.Tx.Exchange do
  alias AbtDidWorkshop.Tx.Helper

  def response_offer(robert, user_addr, beh) do
    asset = Helper.gen_asset(robert, user_addr, beh.asset)
    sender = %{address: robert.address, token: beh.token, asset: asset}
    receiver = %{address: user_addr, token: nil, asset: nil}

    "ExchangeTx"
    |> Helper.get_transaction_to_sign(sender, receiver)
    |> Helper.sign_tx(robert)
    |> Helper.send_tx()
  end

  def response_demand_token(robert, claims) do
    f_sig = Helper.extract_sig()

    case Helper.match?([f_sig], claims) do
      false ->
        %{error: "Need transaction and it's signature."}

      [c] ->
        c["origin"]
        |> Helper.assemble_tx(c["sig"])
        |> Helper.multi_sign(robert)
        |> Helper.send_tx()
    end
  end

  def response_demand_asset(robert, user_addr, demand, offer, claims) do
    f_sig = Helper.extract_sig()

    case Helper.match?([f_sig], claims) do
      [c] ->
        c["origin"]
        |> Helper.assemble_tx(c["sig"])
        |> Helper.multi_sign(robert)
        |> Helper.send_tx()

      false ->
        f_asset = Helper.extract_asset()

        case Helper.match?([f_asset], claims) do
          [c] ->
            sender = %{address: user_addr, token: demand.token, asset: c["did"]}
            offer_asset = Helper.gen_asset(robert, user_addr, offer.asset)
            receiver = %{address: robert.address, token: offer.token, asset: offer_asset}

            "ExchangeTx"
            |> Helper.get_transaction_to_sign(sender, receiver)
            |> Helper.require_signature(user_addr)

          false ->
            %{error: "Need transaction and it's signature."}
        end
    end
  end
end
