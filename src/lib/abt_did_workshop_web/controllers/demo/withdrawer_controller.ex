defmodule AbtDidWorkshopWeb.WithdrawerController do
  use AbtDidWorkshopWeb, :controller
  use ForgeAbi.Unit

  alias AbtDidWorkshop.{WalletUtil, TxUtil, Util, Tether}

  alias ForgeAbi.{
    RequestListTransactions,
    AddressFilter,
    TypeFilter,
    ValidityFilter,
    WithdrawTetherTx,
    TetherTradeInfo
  }

  require Logger

  def index(conn, _) do
    robert = WalletUtil.get_robert()

    state =
      ForgeSdk.get_account_state([address: robert.address], Util.remote_chan()) ||
        %{balance: ForgeAbi.token_to_unit(0)}

    balance = Util.to_token(state.balance)
    robert = Map.put(robert, :balance, balance)

    exchanges = get_exchanges()
    approved = get_approved()
    submitted = get_submitted(approved)

    render(conn, "index.html",
      robert: robert,
      exchanges: exchanges,
      submitted: submitted,
      approved: approved
    )
  end

  def withdraw(conn, %{"hash" => exchange_hash}) do
    robert = WalletUtil.get_robert()
    %{tx: exchange_tx} = ForgeSdk.get_tx(hash: exchange_hash)
    exchange_itx = ForgeAbi.decode_any!(exchange_tx.itx)
    r = exchange_itx.receiver
    tether = r.deposit |> TxUtil.get_tx_hash() |> ForgeSdk.Util.to_tether_address()
    receiver = apply(TetherTradeInfo, :new, [%{value: r.value, assets: r.assets, tether: tether}])

    res =
      WithdrawTetherTx
      |> apply(:new, [
        %{
          from: exchange_tx.from,
          nonce: exchange_tx.nonce,
          chain_id: exchange_tx.chain_id,
          pk: exchange_tx.pk,
          signature: exchange_tx.signature,
          signatures: exchange_tx.signatures,
          sender: exchange_itx.sender,
          receiver: receiver,
          expired_at: exchange_itx.expired_at,
          data: exchange_itx.data
        }
      ])
      |> ForgeSdk.withdraw_tether(wallet: robert, send: :commit, chan: Util.remote_chan())

    case res do
      {:error, reason} ->
        conn
        |> put_flash(:error, "#{inspect(reason)}")
        |> redirect(to: Routes.withdrawer_path(conn, :index))

      hash ->
        store_withdraw_info(tether, exchange_hash, hash)

        conn
        |> put_flash(:info, "Withdraw Tx Hash: #{inspect(hash)}")
        |> redirect(to: Routes.withdrawer_path(conn, :index))
    end
  end

  defp get_exchanges do
    r =
      RequestListTransactions.new(
        address_filter: AddressFilter.new(sender: "z1YgP3zaVdQzB9gC3kHAyTiiMMPZhLzCLDP"),
        type_filter: TypeFilter.new(types: ["exchange_tether"]),
        validity_filter: ValidityFilter.new(validity: 1)
      )

    {indexed_exchanges, _} = ForgeSdk.list_transactions(r)

    indexed_exchanges |> display_exchange() |> filter_withdraw()
  end

  defp display_exchange(list) when is_list(list), do: Enum.map(list, &display_exchange/1)

  defp display_exchange(indexed_tx) do
    itx = ForgeAbi.decode_any!(indexed_tx.tx.itx)
    deposit = itx.receiver.deposit

    tether =
      deposit
      |> TxUtil.get_tx_hash()
      |> ForgeSdk.Util.to_tether_address()

    deposit_itx = ForgeAbi.decode_any!(deposit.itx)

    %{
      hash: indexed_tx.hash,
      depositor: indexed_tx.receiver,
      withdrawer: indexed_tx.sender,
      tether: tether,
      value: Util.to_token(deposit_itx.value),
      commission: Util.to_token(deposit_itx.commission),
      charge: Util.to_token(deposit_itx.charge),
      locktime: ForgeSdk.Util.proto_to_datetime(deposit_itx.locktime)
    }
  end

  defp get_approved do
    r =
      RequestListTransactions.new(
        address_filter: AddressFilter.new(receiver: "z1YgP3zaVdQzB9gC3kHAyTiiMMPZhLzCLDP"),
        type_filter: TypeFilter.new(types: ["approve_tether"]),
        validity_filter: ValidityFilter.new(validity: 1)
      )

    {indexed_approves, _} = ForgeSdk.list_transactions(r, Util.remote_chan())

    indexed_approves |> display_approve()
  end

  defp display_approve(list) when is_list(list), do: Enum.map(list, &display_approve/1)

  defp display_approve(indexed_tx) do
    itx = ForgeAbi.decode_any!(indexed_tx.tx.itx)

    %{
      hash: indexed_tx.hash,
      withdraw: itx.withdraw,
      time: indexed_tx.time
    }
  end

  defp get_submitted(approved) do
    to_be_rejected = Enum.into(approved, %{}, fn appr -> {appr.withdraw, appr} end)

    Tether.get_all()
    |> Enum.reject(fn tether -> Map.has_key?(to_be_rejected, tether.withdraw) end)
  end

  defp filter_withdraw(exchanges) do
    hashs = Enum.map(exchanges, fn %{hash: hash} -> hash end)

    to_be_rejected =
      hashs
      |> Tether.get_by_exchanges()
      |> Enum.filter(fn %{withdraw: withdraw} -> withdraw != nil and withdraw != "" end)
      |> Enum.into(%{}, fn t -> {t.exchange, t} end)

    Enum.reject(exchanges, fn exchange -> Map.has_key?(to_be_rejected, exchange.hash) end)
  end

  defp store_withdraw_info(tether, exchange, withdraw) do
    records = Tether.get_by_exchanges([exchange])

    case records do
      [] ->
        Tether.insert(%{address: tether, exchange: exchange, withdraw: withdraw})

      _ ->
        Enum.each(records, fn record ->
          record
          |> Tether.changeset(%{withdraw: withdraw})
          |> Tether.update()
        end)
    end
  end
end
