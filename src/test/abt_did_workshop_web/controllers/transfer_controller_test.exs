defmodule ForgeWorkshopWeb.TransferControllerTest do
  use ForgeWorkshopWeb.ConnCase

  alias ForgeWorkshopWeb.TestUtil

  @edpoint ForgeWorkshopWeb.Endpoint

  # %{
  #   "consume_asset" => "",
  #   "consume_offer_asset" => "",
  #   "consume_offer_token" => "",
  #   "demo_id" => "2",
  #   "description" => "每日签到，领取奖励",
  #   "exchange_demand_asset" => "",
  #   "exchange_demand_token" => "",
  #   "exchange_offer_asset" => "",
  #   "exchange_offer_token" => "",
  #   "exchange_tether_demand_tether" => "",
  #   "exchange_tether_offer_asset" => "",
  #   "exchange_tether_offer_token" => "",
  #   "init_tx_type" => "",
  #   "name" => "Transfer Tx test",
  #   "poh_asset" => "",
  #   "poh_offer_asset" => "",
  #   "poh_offer_token" => "",
  #   "poh_token" => "",
  #   "transfer_demand_asset" => "",
  #   "transfer_demand_token" => "",
  #   "transfer_offer_asset" => "COUPON20",
  #   "transfer_offer_token" => "10",
  #   "tx_id" => "",
  #   "tx_type" => "TransferTx",
  #   "update_asset" => "",
  #   "update_func" => "",
  #   "update_offer_asset" => "",
  #   "update_offer_token" => ""
  # }

  test "Transfer, offer token and asset, all good", %{conn: conn} do
    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "TransferTest",
        description: "TransferTest",
        tx_type: "TransferTx",
        tx_id: "",
        transfer_offer_asset: "COUPON20",
        transfer_offer_token: "10",
        transfer_demand_asset: "",
        transfer_demand_token: ""
      })

    wallet = ForgeSdk.create_wallet(moniker: "alice", commit: true)

    # Step 1, wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.transfer_path(conn, :start, tx.id))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.transfer_url(@edpoint, :auth_principal, tx.id)

    assert auth_body["requestedClaims"] == [
             %{
               "type" => "authPrincipal",
               "description" => "Please set the authentication principal.",
               "meta" => nil,
               "target" => nil
             }
           ]

    # Step 2, Wallet returns user did
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(auth_body["url"], TestUtil.gen_signed_request(wallet, %{}))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)

    %{
      "status" => "ok",
      "response" => %{
        "hash" => hash,
        "tx" => tx
      }
    } = auth_body

    assert hash != nil
    assert tx != nil
  end
end
