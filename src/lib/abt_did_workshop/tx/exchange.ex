defmodule AbtDidWorkshop.Tx.Exchange do
  @moduledoc false

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

    case Helper.get_claims([f_sig], claims) do
      false ->
        {:error, "Insufficient data to continue."}

      [c] ->
        c["origin"]
        |> Helper.assemble_sig(c["sig"])
        |> Helper.multi_sign(robert)
        |> Helper.send_tx()
    end
  end

  def response_demand_asset(robert, user_addr, demand, offer, claims) do
    f_sig = Helper.extract_sig()

    case Helper.get_claims([f_sig], claims) do
      [c] ->
        c["origin"]
        |> Helper.assemble_sig(c["sig"])
        |> Helper.multi_sign(robert)
        |> Helper.send_tx()

      false ->
        f_asset = Helper.extract_asset()

        case Helper.get_claims([f_asset], claims) do
          [c] ->
            case Helper.validate_asset(demand.asset, c["did"], user_addr) do
              :ok -> do_response_demand_asset(robert, user_addr, demand, offer, c["did"])
              {:error, reason} -> {:error, reason}
            end

          false ->
            {:error, "Insufficient data to continue."}
        end
    end
  end

  def do_response_demand_asset(robert, user_addr, demand, offer, demand_asset) do
    sender = %{address: user_addr, token: demand.token, asset: demand_asset}
    offer_asset = Helper.gen_asset(robert, user_addr, offer.asset)
    receiver = %{address: robert.address, token: offer.token, asset: offer_asset}

    "ExchangeTx"
    |> Helper.get_transaction_to_sign(sender, receiver)
    |> Helper.require_signature(
      user_addr,
      "Pleas confirm this exchange by signing the transaction."
    )
  end
end
