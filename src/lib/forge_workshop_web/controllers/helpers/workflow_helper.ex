defmodule ForgeWorkshopWeb.WorkflowHelper do
  alias ForgeWorkshop.Util

  alias ForgeWorkshop.Step.{
    GenOffer,
    RequireAccount,
    RequireAsset,
    RequireMultiSig,
    RequireSig,
    RequireTether,
    RequireDepositValue
  }

  def gen_workflow(%{tx_type: "PokeTx"}) do
    [
      RequireAccount.new("Please select an account to poke."),
      RequireSig.new("Please confirm this poke by signing the transaction.")
    ]
  end

  def gen_workflow(%{tx_type: "TransferTx", tx_behaviors: [beh]}) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        [
          RequireAccount.new("Please select an account to receive this transfer."),
          GenOffer.new(beh.token, beh.asset)
        ]

      # When robert only demands token from the user.
      beh.behavior == "demand" and Util.empty?(beh.asset) ->
        [
          RequireAccount.new("Please select an account to transfer out."),
          RequireSig.new("Please confirm this transfer by signing the transaction.")
        ]

      # When robert demands asset from the user.
      true ->
        [
          RequireAsset.new("Please select the #{beh.asset} to transfer.", beh.asset),
          RequireSig.new("Please confirm this transfer by signing the transaction")
        ]
    end
  end

  def gen_workflow(%{tx_type: "ExchangeTx", tx_behaviors: behs}) do
    demand = Enum.find(behs, fn beh -> beh.behavior == "demand" end)

    # When robert does not demand asset from the user.
    if Util.empty?(demand.asset) do
      [
        RequireAccount.new("Please select an account to start the exchange."),
        RequireMultiSig.new("Please confirm this exchange by signing the transaction.")
      ]
    else
      # When robert demands asset from the user.
      [
        RequireAsset.new("Please select the #{demand.asset} to exchange.", demand.asset),
        RequireMultiSig.new("Please confirm this exchange by signing the transaction.")
      ]
    end
  end

  def gen_workflow(%{tx_type: "ExchangeTetherTx", tx_behaviors: behs}) do
    demand = Enum.find(behs, fn beh -> beh.behavior == "demand" end)

    [
      RequireTether.new("Please select a deposit tether transaction.", demand.function),
      RequireMultiSig.new("Please confirm this exchange by signing the transaction.")
    ]
  end

  def gen_workflow(%{tx_type: "UpdateAssetTx", tx_behaviors: behs}) do
    update = Enum.find(behs, fn beh -> beh.behavior == "update" end)

    [
      RequireAsset.new("Please select the #{update.asset} to update.", update.asset),
      RequireSig.new("Please confirm this update by signing the transaction.")
    ]
    |> append_offer(behs)
  end

  def gen_workflow(%{tx_type: "ConsumeAssetTx", tx_behaviors: behs}) do
    con = Enum.find(behs, fn beh -> beh.behavior == "consume" end)

    [
      RequireAsset.new("Please select the #{con.asset} to consume.", con.asset),
      RequireMultiSig.new("Please confirm this consumption by signing the transaction.")
    ]
    |> append_offer(behs)
  end

  def gen_workflow(%{tx_type: "ProofOfHolding", tx_behaviors: behs}) do
    poh = Enum.find(behs, fn beh -> beh.behavior == "poh" end)

    cond do
      Util.empty?(poh.asset) == false and Util.empty?(poh.token) == false ->
        [
          RequireAccount.new(
            "Please select an account with minimal #{poh.token} token.",
            poh.token
          ),
          RequireAsset.new("Please prove you have #{poh.asset}.", poh.asset)
        ]

      Util.empty?(poh.asset) == false ->
        [RequireAsset.new("Please prove you have #{poh.asset}.", poh.asset)]

      Util.empty?(poh.token) == false ->
        [
          RequireAccount.new(
            "Please select an account with minimal #{poh.token} token.",
            poh.token
          )
        ]
    end
    |> append_offer(behs)
  end

  def gen_workflow(%{tx_type: "DepositTetherTx"}) do
    [
      RequireDepositValue.new("Please specify the token value you want to deposit."),
      RequireSig.new("Please confirm this deposit by signing this transaction.")
    ]
  end

  defp append_offer(workflow, behs) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)

    case offer do
      nil -> workflow
      _ -> workflow ++ [GenOffer.new(offer.token, offer.asset)]
    end
  end
end
