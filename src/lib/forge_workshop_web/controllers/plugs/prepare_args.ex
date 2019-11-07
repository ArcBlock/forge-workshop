defmodule ForgeWorkshopWeb.Plugs.PrepareArgs do
  @moduledoc """
  Prepare common arguments.
  """
  import Plug.Conn

  alias ForgeWorkshop.WalletUtil

  def init(_) do
  end

  def call(conn, _) do
    assign(conn, :robert, WalletUtil.get_robert())
  end
end
