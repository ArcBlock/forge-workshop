defmodule AbtDidWorkshopWeb.CustodianController do
  use AbtDidWorkshopWeb, :controller
  use ForgeAbi.Unit

  alias AbtDidWorkshop.{Custodian, WalletUtil, Util}

  require Logger

  @anchor1 "zyt4TpbBV6kTaoPBggQpytQfBWQHSfuGmYma"
  @anchor2 "zyt3iSdM8RS2431opc6wy3sou6BKtjXiPYzY"

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
    chan = Util.remote_chan()
    custodian = WalletUtil.gen_wallet()

    changeset =
      Custodian.changeset(%Custodian{}, %{
        address: custodian.address,
        pk: custodian.pk,
        sk: custodian.sk,
        charge: normalize(args["charge"]),
        commission: normalize(args["commission"])
      })

    case WalletUtil.declare_wallet(custodian, args["moniker"], chan) do
      {:error, reason} ->
        conn
        |> put_flash(:error, "#{inspect(reason)}")
        |> render("new.html", changeset: Custodian.changeset(%Custodian{}))

      hash ->
        Logger.warn("Successfully created custodian, hash: #{inspect(hash)} ")

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
    chan = Util.remote_chan()
    res = ForgeSdk.stake_for_node(anchor, amount, wallet: custodian, commit: true, chan: chan)

    case res |> IO.inspect(label: "@@@@") do
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
      get_account_state(custodian) ||
        %{moniker: "", balance: ForgeAbi.token_to_unit(0), deposit_received: nil}

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
      moniker: state.moniker,
      balance: unit_to_token(state.balance)
    }
  end

  defp get_account_state(custodian) do
    chan = Util.remote_chan()

    case ForgeSdk.get_account_state([address: custodian.address], chan) do
      nil ->
        nil

      state ->
        ForgeSdk.display(state)
    end
  end

  defp get_deposit_cap(custodian, anchor) do
    chan = Util.remote_chan()
    addr = ForgeSdk.Util.to_stake_address(custodian.address, anchor)

    case ForgeSdk.get_stake_state([address: addr], chan) do
      nil -> 0
      stake -> stake.balance
    end
  end

  defp normalize(""), do: nil

  defp normalize(value) do
    {v, _} = Float.parse(value)
    v
  end
end
