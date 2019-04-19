defmodule AbtDidWorkshopWeb.TxController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{Demo, Tx}

  def index(conn, %{"demo_id" => demo_id}) do
    demo = Demo.get(demo_id)
    txs = Tx.get_all(demo_id)
    render(conn, "index.html", txs: txs, demo: demo)
  end

  def new(conn, %{"demo_id" => demo_id}) do
    # offers = demo_id |> String.to_integer() |> Tx.get_offer_txs()
    demo = Demo.get(demo_id)
    render(conn, "new.html", changeset: Tx.changeset(%Tx{}, %{}), demo_id: demo_id, tx_id: "", demo: demo)
  end

  def edit(conn, %{"id" => tx_id, "demo_id" => demo_id}) do
    changeset = tx_id |> String.to_integer() |> Tx.get() |> Tx.changeset()
    render(conn, "new.html", changeset: changeset, demo_id: demo_id, tx_id: tx_id)
  end

  def delete(conn, %{"id" => tx_id, "demo_id" => demo_id}) do
    case Tx.delete(tx_id) do
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

  def create(conn, %{"tx" => %{"demo_id" => demo_id, "tx_id" => tx_id, "description" => ""}}),
    do: go_to_new(conn, demo_id, tx_id, "Transaction description cannot be empty.")

  def create(conn, %{"tx" => tx}) do
    do_create(conn, tx)
  end

  defp do_create(conn, %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "PokeTx"} = tx) do
    create_single(conn, demo_id, tx_id, "", "", "", tx)
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
        if demand_token <> demand_asset != "" and offer_token <> offer_asset != "" do
          behaviors =
            to_beh("offer", tx["exchange_offer_asset"], token_offer, tx) ++
              to_beh("demand", tx["exchange_demand_asset"], token_demand, tx)

          do_upsert(conn, demo_id, tx_id, behaviors, tx)
        else
          go_to_new(conn, demo_id, tx_id, "Must offer and demand something at the sametime.")
        end
    end
  end

  defp do_create(
         conn,
         %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "ConsumeAssetTx"} = tx
       ) do
    case tx["consume_asset"] do
      "" ->
        go_to_new(conn, demo_id, tx_id, "Asset title cannot be empty.")

      asset ->
        case parse_token_amount([tx["consume_offer_token"]]) do
          :error ->
            go_to_new(conn, demo_id, tx_id, "The token amount must be positive integer or empty")

          [offer_token] ->
            behaviors =
              to_beh("consume", asset, nil, tx) ++
                to_beh("offer", tx["consume_offer_asset"], offer_token, tx)

            do_upsert(conn, demo_id, tx_id, behaviors, tx)
        end
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
        case parse_token_amount([tx["update_offer_token"]]) do
          :error ->
            go_to_new(conn, demo_id, tx_id, "The token amount must be positive integer or empty")

          [offer_token] ->
            behaviors =
              to_beh("update", tx["update_asset"], nil, tx, tx["update_func"]) ++
                to_beh("offer", tx["update_offer_asset"], offer_token, tx)

            do_upsert(conn, demo_id, tx_id, behaviors, tx)
        end
    end
  end

  defp do_create(
         conn,
         %{"demo_id" => demo_id, "tx_id" => tx_id, "tx_type" => "ProofOfHolding"} = tx
       ) do
    case parse_token_amount([tx["poh_token"], tx["poh_offer_token"]]) do
      :error ->
        go_to_new(conn, demo_id, tx_id, "The token amount must be positive integer or empty")

      [poh_token, offer_token] ->
        case tx["poh_token"] <> tx["poh_asset"] do
          "" ->
            go_to_new(conn, demo_id, tx_id, "The token and asset cannot both be empty.")

          _ ->
            behaviors =
              to_beh("poh", tx["poh_asset"], poh_token, tx) ++
                to_beh("offer", tx["poh_offer_asset"], offer_token, tx)

            do_upsert(conn, demo_id, tx_id, behaviors, tx)
        end
    end
  end

  defp to_beh(beh, asset, token, tx, func \\ nil)
  defp to_beh(_, "", "", _, _), do: []

  defp to_beh(beh, asset, token, tx, func) do
    asset =
      case asset do
        "" -> nil
        asset -> asset
      end

    token =
      case token do
        "" -> nil
        token -> token
      end

    [
      %{
        behavior: beh,
        asset: asset,
        function: func,
        token: token,
        tx_type: tx["tx_type"],
        description: tx["description"]
      }
    ]
  end

  defp create_single(conn, demo_id, tx_id, behavior, token, asset, tx, func \\ nil) do
    behaviors = to_beh(behavior, asset, token, tx, func)
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
      Tx.upsert(transaction, tx_id, demo_id)

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
