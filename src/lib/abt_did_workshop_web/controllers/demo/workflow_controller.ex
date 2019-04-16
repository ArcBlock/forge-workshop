defmodule AbtDidWorkshopWeb.WorkflowController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{AssetUtil, Demo, TxUtil, Util, WalletUtil}
  alias AbtDidWorkshop.Plugs.{PrepareArgs, VerifySig}

  alias AbtDidWorkshop.Step.{
    GenOffer,
    RequireAccount,
    RequireAsset,
    RequireMultiSig,
    RequireSig
  }

  plug(PrepareArgs)
  plug(VerifySig when action != :request)

  def request(conn, %{"userDid" => did, "userPk" => pk}) do
    conn =
      Plug.Conn.assign(conn, :user, %{
        addr: Util.did_to_address(did),
        pk: Multibase.decode!(pk)
      })

    workflow = gen_workflow(conn.assigns.tx)
    reply_step(conn, workflow)
  rescue
    e -> reply({:error, Exception.message(e)}, conn)
  end

  def response_account(conn, _) do
    tx = conn.assigns.tx
    user = conn.assigns.user
    workflow = gen_workflow(tx)
    {current, rest} = get_step(workflow, RequireAccount)

    case WalletUtil.check_balance(current.token, user.address) do
      true -> reply_step(conn, rest)
      false -> reply({:error, "Not enough balance."}, conn)
    end
  end

  def response_asset(conn, _) do
    tx = conn.assigns.tx
    user = conn.assigns.user
    workflow = gen_workflow(tx)
    {current, rest} = get_step(workflow, RequireAsset)

    asset =
      conn.assigns.claims
      |> Enum.find(fn
        %{"type" => "did", "didType" => "asset", "did" => did} -> did != ""
        _ -> false
      end)
      |> Map.get("did")

    validation = AssetUtil.validate_asset(current.title, asset, user.address)

    case validation do
      :ok ->
        conn
        |> Plug.Conn.assign(:asset, asset)
        |> reply_step(rest)

      _ ->
        reply(validation, conn)
    end
  end

  def response_sig(conn, _) do
    claim =
      conn.assigns.claims
      |> Enum.find(fn
        %{"type" => "signature", "sig" => sig, "origin" => origin} -> sig != "" and origin != ""
        _ -> false
      end)

    case claim do
      nil ->
        reply({:error, "Signature is required."}, conn)

      _ ->
        claim["origin"]
        |> TxUtil.assemble_sig(claim["sig"])
        |> TxUtil.send_tx()
        |> reply(conn)
    end
  end

  def response_multi_sig(conn, _) do
    claim =
      conn.assigns.claims
      |> Enum.find(fn
        %{"type" => "signature", "sig" => sig, "origin" => origin} -> sig != "" and origin != ""
        _ -> false
      end)

    case claim do
      nil ->
        reply({:error, "Signature is required."}, conn)

      _ ->
        claim["origin"]
        |> TxUtil.assemble_multi_sig(claim["sig"])
        |> IO.inspect(label: "###")
        |> TxUtil.send_tx()
        |> reply(conn)
    end
  end

  defp reply_step(conn, [%GenOffer{token: token, title: title} | _]) do
    robert = conn.assigns.robert
    user = conn.assigns.user
    offer_asset = TxUtil.gen_asset(robert, user.address, title)
    sender = Map.merge(robert, %{token: token, asset: offer_asset})

    "TransferTx"
    |> TxUtil.get_transaction_to_sign(sender, user)
    |> TxUtil.sign_tx(robert)
    |> TxUtil.send_tx()
    |> reply(conn)
  end

  defp reply_step(conn, [step | _]) do
    step
    |> get_require(conn)
    |> reply(conn)
  end

  defp get_require(step, conn) do
    case step.__struct__ do
      RequireAccount -> {"account", TxUtil.require_account(step.desc, step.token)}
      RequireAsset -> {"asset", TxUtil.require_asset(step.desc, step.title)}
      RequireSig -> {"sig", TxUtil.require_signature(conn, step.desc)}
      RequireMultiSig -> {"multisig", TxUtil.require_multi_sig(conn, step.desc)}
    end
  end

  defp reply({:error, :consensus_rpc_error}, conn) do
    json(conn, %{error: "Consensus error, please try again."})
  end

  defp reply({:error, error}, conn) do
    json(conn, %{error: error})
  end

  defp reply({:ok, response}, conn) do
    json(conn, %{response: response})
  end

  defp reply(:ok, conn) do
    json(conn, %{response: %{result: "ok"}})
  end

  defp reply({action, claims}, conn) do
    tx = conn.assigns.tx
    demo = Demo.get_by_tx_id(tx.id)
    chain_info = ForgeSdk.get_chain_info()
    forge_state = ForgeSdk.get_forge_state()

    app_info =
      demo
      |> Map.take([:name, :subtitle, :description, :icon])
      |> Map.merge(%{
        icon: Util.expand_icon_path(conn, demo.icon),
        chainId: chain_info.network,
        chainVersion: chain_info.version,
        chainHost: Util.get_chainhost(),
        chainToken: forge_state.token.symbol,
        decimals: forge_state.token.decimal
      })

    extra = %{
      url: Util.get_callback() <> "workflow/#{action}/#{tx.id}",
      requestedClaims: claims,
      appInfo: app_info,
      workflow: %{description: tx.description}
    }

    response = %{
      appPk: demo.pk,
      authInfo: AbtDid.Signer.gen_and_sign(demo.did, Multibase.decode!(demo.sk), extra)
    }

    json(conn, response)
  end

  defp gen_workflow(%{tx_type: "PokeTx"}) do
    [
      RequireAccount.new("Please select an account to poke."),
      RequireSig.new("Please confirm this poke by signing the transaction.")
    ]
  end

  defp gen_workflow(%{tx_type: "TransferTx", tx_behaviors: [beh]}) do
    cond do
      # When robert only offers something to the user.
      beh.behavior == "offer" ->
        [
          RequireAccount.new("Please select an account to receive this transfer."),
          GenOffer.new(beh.token, beh.asset)
        ]

      # When robert only demands token from the user.
      beh.behavior == "demand" and beh.asset != "" ->
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

  defp gen_workflow(%{tx_type: "ExchangeTx", tx_behaviors: behs}) do
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

  defp gen_workflow(%{tx_type: "UpdateAssetTx", tx_behaviors: behs}) do
    update = Enum.find(behs, fn beh -> beh.behavior == "update" end)

    [
      RequireAsset.new("Please select the #{update.asset} to update.", update.asset),
      RequireSig.new("Please confirm this update by signing the transaction.")
    ]
    |> append_offer(behs)
  end

  defp gen_workflow(%{tx_type: "ConsumeAssetTx", tx_behaviors: behs}) do
    con = Enum.find(behs, fn beh -> beh.behavior == "consume" end)

    [
      RequireAsset.new("Please select the #{con.asset} to consume.", con.asset),
      RequireMultiSig.new("Please confirm this consumption by signing the transaction.")
    ]
    |> append_offer(behs)
  end

  defp gen_workflow(%{tx_type: "ProofOfHolding", tx_behaviors: behs}) do
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

  defp append_offer(workflow, behs) do
    offer = Enum.find(behs, fn beh -> beh.behavior == "offer" end)

    case offer do
      nil -> workflow
      _ -> workflow ++ [GenOffer.new(offer.token, offer.asset)]
    end
  end

  defp get_step([], _), do: nil

  defp get_step([current | rest], target) do
    case current.__struct__ == target do
      true -> {current, rest}
      _ -> get_step(rest, target)
    end
  end
end
