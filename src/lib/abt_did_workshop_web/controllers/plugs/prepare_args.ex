defmodule AbtDidWorkshop.Plugs.PrepareArgs do
  @moduledoc """
  Prepare common arguments.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias AbtDidWorkshop.{Tx, WalletUtil}

  def init(_) do
  end

  def call(%Plug.Conn{params: %{"id" => id}} = conn, _) do
    assign(conn, :robert, WalletUtil.get_robert())
  end
end
