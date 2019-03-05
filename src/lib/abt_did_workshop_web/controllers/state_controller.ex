defmodule AbtDidWorkshopWeb.StateController do
  use AbtDidWorkshopWeb, :controller

  def account(conn, %{"addr" => addr}) do
    account = AbtDidWorkshop.WalletUtil.get_account_state(addr)
    {assets, _} = ForgeSdk.get_assets(owner_address: addr)

    certs =
      Enum.into(assets, %{}, fn asset ->
        {_, cert} =
          [address: asset.address]
          |> ForgeSdk.get_asset_state()
          |> Map.get(:data)
          |> ForgeAbi.decode_any()

        {asset.address, [cert.title, cert.content]}
      end)

    json(conn, Map.put(account, :assets, certs))
  end
end
