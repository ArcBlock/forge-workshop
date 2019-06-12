defmodule ForgeWorkshopWeb.CustodianController do
  use ForgeWorkshopWeb, :controller
  use ForgeAbi.Unit

  alias ForgeWorkshop.{Custodian, WalletUtil, Tether, TxUtil, Util}

  alias ForgeAbi.{
    AddressFilter,
    ApproveTetherTx,
    ExchangeTetherTx,
    IndexedTransaction,
    RequestListTransactions,
    TetherExchangeInfo,
    Transaction,
    TypeFilter,
    ValidityFilter
  }

  require Logger

  @anchor1 "zyt4TpbBV6kTaoPBggQpytQfBWQHSfuGmYma"
  @anchor2 "zyt3iSdM8RS2431opc6wy3sou6BKtjXiPYzY"

  def get(conn, %{"address" => address}) do
    custodian = address |> Custodian.get() |> enrich()

    {indexed_tethers, _} = ForgeSdk.list_tethers([custodian: address, available: true], "remote")
    tethers = display_tether(indexed_tethers)

    r =
      RequestListTransactions.new(
        address_filter: AddressFilter.new(receiver: address),
        type_filter: TypeFilter.new(types: ["withdraw_tether"]),
        validity_filter: ValidityFilter.new(validity: 1)
      )

    {indexed_withdraw, _} = ForgeSdk.list_transactions(r, "remote")
    withdraws = indexed_withdraw |> display_withdraw() |> filter_approve()
    render(conn, "one.html", custodian: custodian, tethers: tethers, withdraws: withdraws)
  end

  def index(conn, _) do
    custodians =
      Custodian.get_all()
      |> Enum.map(&enrich/1)

    render(conn, "index.html", custodians: custodians)
  end

  def new(conn, _) do
    changeset = Custodian.changeset(%Custodian{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"custodian" => args}) do
    custodian = WalletUtil.gen_wallet()

    changeset =
      Custodian.changeset(%Custodian{}, %{
        address: custodian.address,
        pk: custodian.pk,
        sk: custodian.sk,
        moniker: args["moniker"],
        charge: normalize(args["charge"]),
        commission: normalize(args["commission"])
      })

    case WalletUtil.declare_wallet(custodian, args["moniker"], "remote") do
      {:error, reason} ->
        conn
        |> put_flash(:error, "#{inspect(reason)}")
        |> render("new.html", changeset: Custodian.changeset(%Custodian{}))

      hash ->
        Logger.info("Successfully created custodian, hash: #{inspect(hash)} ")
        WalletUtil.raise_balance(custodian.address, 200, "remote")

        case Custodian.insert(changeset) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Successfully created custodian.")
            |> redirect(to: Routes.custodian_path(conn, :index))

          {:error, changeset} ->
            render(conn, "new.html", changeset: changeset)
        end
    end
  end

  def edit(conn, %{"address" => address}) do
    render(conn, "edit.html", address: address)
  end

  def update(conn, params) do
    %{"address" => address, "amount" => amount, "anchor" => anchor} = params
    do_update(conn, address, Float.parse(amount), anchor)
  end

  def verify(conn, %{"hash" => hash, "address" => address}) do
    case ForgeSdk.get_tx(hash: hash) do
      nil ->
        conn
        |> put_flash(:error, "The Exchange Tether Tx is NOT found.")
        |> redirect(to: Routes.custodian_path(conn, :get, address))

      %{code: :ok} ->
        conn
        |> put_flash(:info, "The Exchange Tether Tx is valid.")
        |> redirect(to: Routes.custodian_path(conn, :get, address))

      _ ->
        conn
        |> put_flash(:error, "The Exchange Tether Tx is NOT valid.")
        |> redirect(to: Routes.custodian_path(conn, :get, address))
    end
  end

  def approve(conn, %{"hash" => withdraw_hash, "address" => address}) do
    custodian = Custodian.get(address)
    itx = apply(ApproveTetherTx, :new, [[withdraw: withdraw_hash]])
    res = ForgeSdk.approve_tether(itx, wallet: custodian, conn: "remote", send: :commit)

    case res do
      {:error, reason} ->
        conn
        |> put_flash(:error, "Approve Tether Failed: #{inspect(reason)}")
        |> redirect(to: Routes.custodian_path(conn, :get, address))

      hash ->
        store_approve_info(withdraw_hash, hash)

        conn
        |> put_flash(:info, "Approve Tether Tx: #{hash}")
        |> redirect(to: Routes.custodian_path(conn, :get, address))
    end
  end

  def do_update(conn, address, _, "") do
    conn
    |> put_flash(:error, "Please select an anchor.")
    |> render("edit.html", address: address)
  end

  def do_update(conn, address, {v, ""}, anchor) do
    case v <= 0 do
      true ->
        conn
        |> put_flash(:error, "Unstake is not supported yet.")
        |> render("edit.html", address: address)

      false ->
        stake_to_anchor(conn, address, anchor, trunc(v))
    end
  end

  def do_update(conn, address, {_, _}, _anchor) do
    conn
    |> put_flash(:error, "Invalid amount.")
    |> render("edit.html", address: address)
  end

  defp stake_to_anchor(conn, address, anchor, amount) do
    custodian = Custodian.get(address)
    # value = ForgeAbi.token_to_unit(amount)
    res = ForgeSdk.stake_for_node(anchor, amount, wallet: custodian, commit: true, conn: "remote")

    case res do
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to stake to anchor, reason: #{inspect(reason)}")
        |> render("edit.html", address: address)

      _ ->
        conn
        |> put_flash(:info, "Successed.")
        |> redirect(to: Routes.custodian_path(conn, :index))
    end
  end

  defp enrich(custodian) do
    state =
      get_account_state(custodian) || %{balance: ForgeAbi.token_to_unit(0), deposit_received: nil}

    received =
      case state.deposit_received do
        nil -> 0
        _ -> state.deposit_received
      end

    cap = get_deposit_cap(custodian, @anchor1) + get_deposit_cap(custodian, @anchor2)

    %{
      pk: custodian.pk,
      address: custodian.address,
      cap: unit_to_token(cap),
      received: unit_to_token(received),
      moniker: custodian.moniker,
      balance: unit_to_token(state.balance)
    }
  end

  defp get_account_state(custodian) do
    case ForgeSdk.get_account_state([address: custodian.address], "remote") do
      nil ->
        nil

      state ->
        ForgeSdk.display(state)
    end
  end

  defp get_deposit_cap(custodian, anchor) do
    addr = ForgeSdk.Util.to_stake_address(custodian.address, anchor)

    case ForgeSdk.get_stake_state([address: addr], "remote") do
      nil -> 0
      stake -> stake.balance
    end
  end

  defp normalize(""), do: nil

  defp normalize(value) do
    {v, _} = Float.parse(value)
    v
  end

  defp display_withdraw(list) when is_list(list), do: Enum.map(list, &display_withdraw/1)

  defp display_withdraw(%IndexedTransaction{} = indexed_withdraw) do
    %{tx: withdraw_tx} = indexed_withdraw
    withdraw_itx = ForgeAbi.decode_any!(withdraw_tx.itx)
    tether = withdraw_itx.receiver.tether
    tether_state = ForgeSdk.get_tether_state([address: tether], "remote")
    %{tx: deposit_tx} = ForgeSdk.get_tx([hash: tether_state.hash], "remote")
    exchange = to_exchange(withdraw_itx, deposit_tx)
    exchange_hash = TxUtil.get_tx_hash(exchange)

    %{
      address: tether_state.address,
      available: tether_state.available,
      depositor: tether_state.depositor,
      withdrawer: tether_state.withdrawer,
      value: Util.to_token(tether_state.value),
      commission: Util.to_token(tether_state.commission),
      charge: Util.to_token(tether_state.charge),
      target: tether_state.target,
      locktime: ForgeSdk.Util.proto_to_datetime(tether_state.locktime),
      time: indexed_withdraw.time,
      withdraw_hash: indexed_withdraw.hash,
      exchange_hash: exchange_hash
    }
  end

  defp to_exchange(withdraw_itx, deposit_tx) do
    receiver =
      apply(TetherExchangeInfo, :new, [
        [
          assets: withdraw_itx.receiver.assets,
          value: withdraw_itx.receiver.value,
          deposit: deposit_tx
        ]
      ])

    itx =
      apply(ExchangeTetherTx, :new, [
        [
          sender: withdraw_itx.sender,
          receiver: receiver,
          expired_at: withdraw_itx.expired_at
        ]
      ])

    Transaction.new(
      chain_id: withdraw_itx.chain_id,
      from: withdraw_itx.from,
      itx: ForgeAbi.encode_any!(itx, "fg:t:exchange_tether"),
      nonce: withdraw_itx.nonce,
      pk: withdraw_itx.pk,
      signature: withdraw_itx.signature,
      signatures: withdraw_itx.signatures
    )
  end

  defp display_tether(list) when is_list(list), do: Enum.map(list, &display_tether/1)

  defp display_tether(tether) do
    t = ForgeSdk.display(tether)

    t
    |> Map.put(:charge, Util.to_token(t.charge))
    |> Map.put(:commission, Util.to_token(t.commission))
    |> Map.put(:value, Util.to_token(t.value))
  end

  defp filter_approve(withdraws) do
    hashs = Enum.map(withdraws, fn %{withdraw_hash: hash} -> hash end)

    to_be_rejected =
      hashs
      |> Tether.get_by_withdraws()
      |> Enum.filter(fn %{approve: approve} -> approve != nil and approve != "" end)
      |> Enum.into(%{}, fn t -> {t.withdraw, t} end)

    Enum.reject(withdraws, fn withdraw -> Map.has_key?(to_be_rejected, withdraw.withdraw_hash) end)
  end

  defp store_approve_info(withdraw, approve) do
    records = Tether.get_by_withdraws([withdraw])

    Enum.each(records, fn record ->
      record
      |> Tether.changeset(%{approve: approve})
      |> Tether.update()
    end)
  end
end
