defmodule AbtDidWorkshopWeb.WorkflowController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{AssetUtil, Custodian, Demo, TxUtil, Util, WalletUtil}
  alias AbtDidWorkshop.Plugs.{PrepareArgs, PrepareTx, VerifySig}

  alias AbtDidWorkshop.Step.{
    GenOffer,
    RequireAccount,
    RequireAsset,
    RequireMultiSig,
    RequireSig,
    RequireTether,
    RequireDepositValue
  }

  alias AbtDidWorkshopWeb.WorkflowHelper
  alias ForgeAbi.Util.BigInt
  alias ForgeAbi.Transaction

  plug(PrepareArgs)
  plug(PrepareTx)
  plug(VerifySig when action != :request)

  def request(conn, %{"userDid" => did, "userPk" => pk}) do
    conn =
      Plug.Conn.assign(conn, :user, %{
        addr: Util.did_to_address(did),
        pk: Multibase.decode!(pk)
      })

    tx = conn.assigns.tx
    workflow = WorkflowHelper.gen_workflow(tx)
    reply_step(conn, workflow)
    # rescue
    #   e -> reply({:error, Exception.message(e)}, conn)
  end

  def response_account(conn, _) do
    tx = conn.assigns.tx
    user = conn.assigns.user
    workflow = WorkflowHelper.gen_workflow(tx)
    {current, rest} = get_step(workflow, RequireAccount)

    case WalletUtil.check_balance(current.token, user.address) do
      true -> reply_step(conn, rest)
      false -> reply({:error, "Not enough balance."}, conn)
    end
  end

  def response_asset(conn, _) do
    tx = conn.assigns.tx
    user = conn.assigns.user
    workflow = WorkflowHelper.gen_workflow(tx)
    {current, rest} = get_step(workflow, RequireAsset)

    asset =
      conn.assigns.claims
      |> Enum.find(fn
        %{"type" => "did", "did_type" => "asset", "did" => did} -> did != ""
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
        |> multi_sign(conn)
        |> TxUtil.send_tx()
        |> async_offer(conn, RequireSig)
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
        |> TxUtil.send_tx()
        |> async_offer(conn, RequireMultiSig)
        |> reply(conn)
    end
  end

  def response_deposit_value(conn, _) do
    claim =
      conn.assigns.claims
      |> Enum.find(fn
        %{"type" => "token", "value" => value} -> value != ""
        _ -> false
      end)

    cond do
      claim == nil ->
        reply({:error, "Deposit value is required."}, conn)

      :error == Float.parse(claim["value"]) ->
        reply({:error, "Invalid token value."}, conn)

      true ->
        {value, _} = Float.parse(claim["value"])
        [_, rest] = WorkflowHelper.gen_workflow(conn.assigns.tx)

        conn
        |> Plug.Conn.assign(:deposit_value, value)
        |> reply_step([rest])
    end
  end

  def response_tether(conn, _) do
    claim =
      conn.assigns.claims
      |> Enum.find(fn
        %{"type" => "deposit", "deposit" => deposit} -> deposit != ""
        _ -> false
      end)

    tx = conn.assigns.tx
    workflow = WorkflowHelper.gen_workflow(tx)
    {current, rest} = get_step(workflow, RequireTether)

    deposit_tx = claim["deposit"] |> Multibase.decode!() |> Transaction.decode()

    case check_deposit(deposit_tx, current.value) do
      "ok" ->
        conn
        |> Plug.Conn.assign(:deposit, deposit_tx)
        |> reply_step(rest)

      error ->
        reply({:error, error}, conn)
    end
  end

  defp multi_sign(tx, conn) do
    case tx.itx.type_url do
      "fg:t:deposit_tether" -> TxUtil.multi_sign(tx, conn.assigns.custodian)
      _ -> tx
    end
  end

  defp async_offer(result, conn, currentStep) do
    tx = conn.assigns.tx
    workflow = WorkflowHelper.gen_workflow(tx)
    {_, rest} = get_step(workflow, currentStep)

    case rest do
      [%GenOffer{token: token, title: title} | _] -> do_async_offer(result, conn, token, title)
      _ -> result
    end
  end

  defp do_async_offer({:ok, %{hash: hash}} = result, conn, token, title) do
    Task.async(fn ->
      Process.sleep(10_000)
      tx = ForgeSdk.get_tx(hash: hash)

      if tx != nil && tx.code == 0 do
        robert = conn.assigns.robert
        user = conn.assigns.user

        robert
        |> TxUtil.robert_offer(user, token, title)
      end
    end)

    result
  end

  defp do_async_offer(result, _, _, _), do: result

  defp reply_step(conn, [%GenOffer{token: token, title: title} | _]) do
    robert = conn.assigns.robert
    user = conn.assigns.user

    robert
    |> TxUtil.robert_offer(user, token, title)
    |> reply(conn)
  end

  defp reply_step(conn, [step | _]) do
    step
    |> get_require(conn)
    |> reply(conn)
  end

  defp reply_step(conn, []) do
    reply(:ok, conn)
  end

  defp get_require(step, conn) do
    case step.__struct__ do
      RequireAccount -> {"account", TxUtil.require_account(step.desc, step.token)}
      RequireAsset -> {"asset", TxUtil.require_asset(step.desc, step.title)}
      RequireSig -> {"sig", TxUtil.require_signature(conn, step.desc)}
      RequireMultiSig -> {"multisig", TxUtil.require_multi_sig(conn, step.desc)}
      RequireTether -> {"tether", TxUtil.require_tether(step.desc, step.value)}
      RequireDepositValue -> {"deposit", TxUtil.require_deposit_value(step.desc)}
    end
  end

  defp reply({:error, :consensus_rpc_error}, conn) do
    tx = conn.assigns.tx

    error =
      case tx.tx_type do
        "PokeTx" -> "Consensus error, you can only poke once a day."
        _ -> "Consensus error, please try again."
      end

    json(conn, %{error: error})
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
    app_info = get_app_info(conn, tx.id)
    chain_info = get_chain_info(tx.id)
    wallet = get_app_wallet(tx.id)

    extra = %{
      url: Util.get_callback() <> "workflow/#{action}/#{tx.id}",
      requestedClaims: claims,
      appInfo: app_info,
      chainInfo: chain_info,
      workflow: %{description: tx.description}
    }

    do_reply(conn, extra, wallet)
  end

  defp do_reply(conn, extra, wallet) do
    response = %{
      appPk: Multibase.encode!(wallet.pk, :base58_btc),
      authInfo: AbtDid.Signer.gen_and_sign(wallet.address, wallet.sk, extra)
    }

    json(conn, response)
  end

  defp get_step([], _), do: nil

  defp get_step([current | rest], target) do
    case current.__struct__ == target do
      true -> {current, rest}
      _ -> get_step(rest, target)
    end
  end

  defp get_app_wallet(tx_id) when is_integer(tx_id) do
    demo = Demo.get_by_tx_id(tx_id)

    %{
      address: demo.did,
      sk: Multibase.decode!(demo.sk),
      pk: Multibase.decode!(demo.pk)
    }
  end

  defp get_app_wallet(address) do
    Custodian.get(address)
  end

  defp get_app_info(conn, tx_id) when is_integer(tx_id) do
    demo = Demo.get_by_tx_id(tx_id)

    demo
    |> Map.take([:name, :subtitle, :description, :icon])
    |> Map.merge(%{
      icon: Util.expand_icon_path(conn, demo.icon)
    })
  end

  defp get_app_info(_, _) do
    %{name: "TBA Chain", description: "The test chain for ABT."}
  end

  defp get_chain_info(tx_id) when is_integer(tx_id) do
    chain_info = ForgeSdk.get_chain_info()
    forge_state = ForgeSdk.get_forge_state()

    chain_info
    |> do_get_chain_info(forge_state)
    |> Map.put(:chainHost, Util.get_chainhost())
  end

  defp get_chain_info(_) do
    chan = Util.remote_chan()
    chain_info = ForgeSdk.get_chain_info(chan)
    forge_state = ForgeSdk.get_forge_state(chan)

    chain_info
    |> do_get_chain_info(forge_state)
    |> Map.put(:chainHost, Util.get_chainhost(:remote))
  end

  defp do_get_chain_info(chain_info, forge_state) do
    %{
      chainId: chain_info.network,
      chainVersion: chain_info.version,
      chainToken: forge_state.token.symbol,
      decimals: forge_state.token.decimal
    }
  end

  defp check_deposit(deposit, value) do
    tether_address =
      deposit
      |> TxUtil.get_tx_hash()
      |> ForgeSdk.Util.to_tether_address()

    chan = Util.remote_chan()

    tether = [address: tether_address] |> ForgeSdk.get_tether_state(chan)

    cond do
      tether == nil -> "Deposited tether not found."
      tether.available != true -> "Invalid tether."
      BigInt.to_int(tether.value) != str_to_unit(value) -> "Invalid tether value."
      true -> "ok"
    end
  end

  defp str_to_unit(str) do
    {value, _} = Float.parse(str)

    value
    |> ForgeAbi.token_to_unit()
    |> BigInt.to_int()
  end
end
