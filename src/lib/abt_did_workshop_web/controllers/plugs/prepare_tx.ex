defmodule AbtDidWorkshop.Plugs.PrepareTx do
  @moduledoc """
  Prepare common arguments.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias AbtDidWorkshop.{Custodian, Tx}

  def init(_) do
  end

  def call(%Plug.Conn{params: %{"id" => id}} = conn, _) do
    case AbtDid.is_valid?(id) do
      true ->
        custodian = Custodian.get(id)

        conn
        |> assign(:custodian, custodian)
        |> assign(:tx, %{
          tx_type: "DepositTetherTx",
          id: custodian.address,
          description: "You are depositing tether to #{custodian.moniker}."
        })

      false ->
        prepare_tx(conn, id)
    end
  end

  defp prepare_tx(conn, tx_id) do
    tx_id = String.to_integer(tx_id)

    case Tx.get(tx_id) do
      nil ->
        conn
        |> json({:error, "Cannot find transaction."})
        |> halt()

      tx ->
        conn
        |> assign(:tx, tx)
    end
  end
end
