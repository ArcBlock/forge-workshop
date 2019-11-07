defmodule ForgeWorkshopWeb.TransferControllerTest do
  use ForgeWorkshopWeb.ConnCase

  alias ForgeWorkshopWeb.TestUtil
  alias ForgeWorkshop.{TxUtil, WalletUtil}

  @edpoint ForgeWorkshopWeb.Endpoint

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

  test "Transfer, only demands token, all good", %{conn: conn} do
    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "TransferTest",
        description: "TransferTest",
        tx_type: "TransferTx",
        tx_id: "",
        transfer_offer_asset: "",
        transfer_offer_token: "",
        transfer_demand_asset: "",
        transfer_demand_token: "10"
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
    assert auth_body["url"] === Routes.transfer_url(@edpoint, :return_sig, tx.id)

    [
      %{
        "description" => "Please confirm this transfer by signing the transaction.",
        "digest" => digest,
        "meta" => nil,
        "method" => "keccak",
        "origin" => origin,
        "type" => "signature",
        "typeUrl" => "fg:t:transaction"
      }
    ] = auth_body["requestedClaims"]

    # Step 3, Wallet returns signature
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(
        auth_body["url"],
        TestUtil.gen_signed_request(wallet, %{
          "requestedClaims" => [
            %{
              "type" => "signature",
              "origin" => origin,
              "sig" => TestUtil.sign(wallet, digest)
            }
          ]
        })
      )
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

  test "Transfer, demands token and asset, all good", %{conn: conn} do
    asset_title = "COUPON20"

    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "TransferTest",
        description: "TransferTest",
        tx_type: "TransferTx",
        tx_id: "",
        transfer_offer_asset: "",
        transfer_offer_token: "",
        transfer_demand_asset: asset_title,
        transfer_demand_token: "10"
      })

    wallet = ForgeSdk.create_wallet(moniker: "alice", commit: true)
    robert = WalletUtil.get_robert()
    {:ok, %{hash: hash}} = TxUtil.robert_offer(robert, wallet, 0, "COUPON20")
    %{tx: %{itx: %{assets: [asset]}}} = ForgeSdk.get_tx(hash: hash) |> ForgeSdk.display()

    # Step 1, wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.transfer_path(conn, :start, tx.id))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.transfer_url(@edpoint, :auth_principal, tx.id)

    assert [
             %{
               "type" => "authPrincipal",
               "description" => "Please set the authentication principal.",
               "meta" => nil,
               "target" => nil
             }
           ] == auth_body["requestedClaims"]

    # Step 2, Wallet returns user did
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(auth_body["url"], TestUtil.gen_signed_request(wallet, %{}))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.transfer_url(@edpoint, :return_asset, tx.id)

    assert [
             %{
               "description" => "Please select the #{asset_title} to transfer.",
               "meta" => nil,
               "type" => "asset"
             }
           ] == auth_body["requestedClaims"]

    # Step 3, Wallet returns asset address
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(
        auth_body["url"],
        TestUtil.gen_signed_request(wallet, %{
          "requestedClaims" => [%{"type" => "asset", "asset" => asset}]
        })
      )
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.transfer_url(@edpoint, :return_sig, tx.id)

    [
      %{
        "description" => "Please confirm this transfer by signing the transaction.",
        "digest" => digest,
        "meta" => nil,
        "method" => "keccak",
        "origin" => origin,
        "type" => "signature",
        "typeUrl" => "fg:t:transaction"
      }
    ] = auth_body["requestedClaims"]

    # Step 4, Wallet returns signature
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(
        auth_body["url"],
        TestUtil.gen_signed_request(wallet, %{
          "requestedClaims" => [
            %{
              "type" => "signature",
              "origin" => origin,
              "sig" => TestUtil.sign(wallet, digest)
            }
          ]
        })
      )
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
