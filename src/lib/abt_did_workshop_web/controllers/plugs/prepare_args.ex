defmodule AbtDidWorkshop.Plugs.PrepareArgs do
  import Plug.Conn
  import Phoenix.Controller

  alias AbtDidWorkshop.{Tx, WalletUtil}

  def init(_) do
  end

  def call(%Plug.Conn{params: %{"id" => id}} = conn, _) do
    tx_id = String.to_integer(id)

    case Tx.get(tx_id) do
      nil ->
        conn
        |> json({:error, "Cannot find transaction."})
        |> halt()

      tx ->
        conn
        |> assign(:tx, tx)
        |> assign(:robert, WalletUtil.get_robert())
    end
  end
end
