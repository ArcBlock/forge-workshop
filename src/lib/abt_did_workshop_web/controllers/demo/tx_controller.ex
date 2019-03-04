defmodule AbtDidWorkshopWeb.TxController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop
  alias AbtDidWorkshop.{Tables.DemoTable, Tables.TxTable, Tx}

  def index(conn, %{"demo_id" => demo_id}) do
    demo = DemoTable.get(demo_id)
    txs = TxTable.get_all(demo_id)
    render(conn, "index.html", txs: txs, demo: demo)
  end

  def new(conn, %{"demo_id" => demo_id}) do
    # offers = demo_id |> String.to_integer() |> TxTable.get_offer_txs()
    render(conn, "new.html", changeset: Tx.changeset(%Tx{}, %{}), demo_id: demo_id, tx_id: "")
  end

  def edit(conn, %{"id" => tx_id, "demo_id" => demo_id}) do
    changeset = tx_id |> String.to_integer() |> TxTable.get() |> Tx.changeset()
    render(conn, "new.html", changeset: changeset, demo_id: demo_id, tx_id: tx_id)
  end

  def delete(conn, %{"id" => tx_id, "demo_id" => demo_id}) do
    case TxTable.delete(tx_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Transaction Deleted.")
        |> redirect(to: Routes.tx_path(conn, :index, demo_id: demo_id))

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to delete Tx. Error: #{inspect(reason)}")
        |> redirect(to: Routes.tx_path(conn, :index, demo_id: demo_id))
    end
  end

  def create(conn, %{"tx" => %{"demo_id" => demo_id, "tx_id" => tx_id, "name" => ""}}),
    do: go_to_new(conn, demo_id, tx_id, "Transaction name cannot be empty.")

  def create(conn, %{"tx" => %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => ""}}),
    do: go_to_new(conn, demo_id, tx_id, "Transaction type cannot be empty.")

  def create(conn, %{"tx" => tx}) do
    do_create(conn, tx)
  end

  defp do_create(conn, %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "TransferTx"} = tx) do
    offer_asset = tx["transfer_offer_asset"]
    offer_token = tx["transfer_offer_token"]
    demand_asset = tx["transfer_demand_asset"]
    demand_token = tx["transfer_demand_token"]

    case parse_token_amount([offer_token, demand_token]) do
      :error ->
        go_to_new(conn, demo_id, tx_id, "The token amount must be positive integer or empty")

      [token_offer, token_demand] ->
        cond do
          demand_token <> demand_asset != "" and offer_token <> offer_asset != "" ->
            go_to_new(conn, demo_id, tx_id, "You cannot offer and demand at the same time.")

          demand_token <> demand_asset != "" ->
            create_single(conn, demo_id, tx_id, "demand", token_demand, demand_asset, tx)

          offer_token <> offer_asset != "" ->
            create_single(conn, demo_id, tx_id, "offer", token_offer, offer_asset, tx)

          true ->
            go_to_new(conn, demo_id, tx_id, "Offer and demand cannot be empty at the same time.")
        end
    end
  end

  defp do_create(conn, %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "ExchangeTx"} = tx) do
    offer_asset = tx["exchange_offer_asset"]
    offer_token = tx["exchange_offer_token"]
    demand_asset = tx["exchange_demand_asset"]
    demand_token = tx["exchange_demand_token"]

    case parse_token_amount([offer_token, demand_token]) do
      :error ->
        go_to_new(conn, demo_id, tx_id, "The token amount must be positive integer or empty")

      [token_offer, token_demand] ->
        cond do
          demand_token <> demand_asset != "" and offer_token <> offer_asset != "" ->
            create_exchange(conn, demo_id, tx_id, "both", token_offer, token_demand, tx)

          demand_token <> demand_asset != "" ->
            create_exchange(conn, demo_id, tx_id, "demand", token_offer, token_demand, tx)

          offer_token <> offer_asset != "" ->
            create_exchange(conn, demo_id, tx_id, "offer", token_offer, token_demand, tx)

          true ->
            go_to_new(conn, demo_id, tx_id, "Offer and demand cannot be empty at the same time.")
        end
    end
  end

  defp do_create(
         conn,
         %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "ActivateAssetTx"} = tx
       ) do
    case tx["activate_asset"] do
      "" -> go_to_new(conn, demo_id, tx_id, "Asset title cannot be empty.")
      asset -> create_single(conn, demo_id, tx_id, "activate", nil, asset, tx)
    end
  end

  defp do_create(
         conn,
         %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "UpdateAssetTx"} = tx
       ) do
    valid =
      try do
        {f, _} = Code.eval_string(tx["update_func"])
        is_function(f)
      rescue
        _ -> false
      end

    cond do
      tx["update_asset"] == "" ->
        go_to_new(conn, demo_id, tx_id, "Asset title cannot be empty.")

      valid == false ->
        go_to_new(conn, demo_id, tx_id, "Invalid function.")

      true ->
        create_single(
          conn,
          demo_id,
          tx_id,
          "update",
          nil,
          tx["update_asset"],
          tx,
          tx["update_func"]
        )
    end
  end

  defp do_create(
         conn,
         %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "ProofOfHolding"} = tx
       ) do
    case parse_token_amount([tx["poh_token"]]) do
      :error ->
        go_to_new(conn, demo_id, tx_id, "The token amount must be positive integer or empty")

      [token] ->
        case tx["poh_token"] <> tx["poh_asset"] do
          "" -> go_to_new(conn, demo_id, tx_id, "The token and asset cannot both be empty.")
          _ -> create_single(conn, demo_id, tx_id, "poh", token, tx["poh_asset"], tx)
        end
    end
  end

  defp create_single(conn, demo_id, tx_id, behavior, token, asset, tx, func \\ nil) do
    behaviors = [
      %{
        behavior: behavior,
        asset: asset,
        function: func,
        token: token,
        tx_type: tx["tx_type"]
      }
    ]

    do_upsert(conn, demo_id, tx_id, behaviors, tx)
  end

  defp create_exchange(conn, demo_id, tx_id, beh, token_offer, token_demand, tx) do
    offer = %{
      behavior: "offer",
      asset: tx["exchange_offer_asset"],
      token: token_offer,
      tx_type: tx["tx_type"]
    }

    demand = %{
      behavior: "demand",
      asset: tx["exchange_demand_asset"],
      token: token_demand,
      tx_type: tx["tx_type"]
    }

    behaviors =
      case beh do
        "both" -> [offer, demand]
        "offer" -> [offer]
        "demand" -> [demand]
      end

    do_upsert(conn, demo_id, tx_id, behaviors, tx)
  end

  defp do_upsert(conn, demo_id, tx_id, behaviors, tx) do
    transaction = %{
      description: tx["description"],
      name: tx["name"],
      tx_type: tx["tx_type"],
      tx_behaviors: behaviors
    }

    try do
      TxTable.upsert(transaction, tx_id, demo_id)

      conn
      |> put_flash(:info, "Transaction upserted.")
      |> redirect(to: Routes.tx_path(conn, :index, demo_id: demo_id))
    rescue
      e ->
        conn
        |> put_flash(:error, "Failed to upsert transaction.")
        |> render("new.html", changeset: e.changeset, demo_id: demo_id, tx_id: tx_id)
    end
  end

  defp go_to_new(conn, demo_id, tx_id, error) do
    conn
    |> put_flash(:error, error)
    |> redirect(to: Routes.tx_path(conn, :new, demo_id: demo_id, tx_id: tx_id))
  end

  defp parse_token_amount(amounts) do
    Enum.map(
      amounts,
      fn
        "" ->
          nil

        a ->
          res = String.to_integer(a)

          if res > 0 do
            res
          else
            raise "Must be positive number."
          end
      end
    )
  rescue
    _ -> :error
  end
end
