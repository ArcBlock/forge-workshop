defmodule ForgeWorkshopWeb.PohControllerTest do
  use ForgeWorkshopWeb.ConnCase

  alias ForgeWorkshopWeb.TestUtil
  alias ForgeWorkshop.{TxUtil, WalletUtil}

  @edpoint ForgeWorkshopWeb.Endpoint

  test "Poh, require account only, all good", %{conn: conn} do
    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "PohTest",
        description: "PohTest",
        tx_type: "ProofOfHolding",
        tx_id: "",
        poh_asset: "",
        poh_offer_asset: "",
        poh_offer_token: "",
        poh_token: "10"
      })

    wallet = ForgeSdk.create_wallet(moniker: "alice", commit: true)
    Process.sleep(4000)

    # Step 1, wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.poh_path(conn, :start, tx.id))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.poh_url(@edpoint, :auth_principal, tx.id)

    assert [
             %{
               "type" => "authPrincipal",
               "description" => "Please set the authentication principal with minimal 10 token.",
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
    %{"status" => "ok"} = auth_body
  end

  test "Poh, require asset only, all good", %{conn: conn} do
    asset_title = "COUPON20"

    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "PohTest",
        description: "PohTest",
        tx_type: "ProofOfHolding",
        tx_id: "",
        poh_asset: asset_title,
        poh_offer_asset: "",
        poh_offer_token: "",
        poh_token: ""
      })

    wallet = ForgeSdk.create_wallet(moniker: "alice", commit: true)
    robert = WalletUtil.get_robert()
    {:ok, %{hash: hash}} = TxUtil.robert_offer(robert, wallet, 0, asset_title)
    %{tx: %{itx: %{assets: [asset]}}} = ForgeSdk.get_tx(hash: hash) |> ForgeSdk.display()

    # Step 1, wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.poh_path(conn, :start, tx.id))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.poh_url(@edpoint, :auth_principal, tx.id)

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
    assert auth_body["url"] === Routes.poh_url(@edpoint, :return_asset, tx.id)

    assert [
             %{
               "description" => "Please return the address of a #{asset_title} owned by you.",
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

    %{"status" => "ok"} = auth_body
  end

  test "Poh, require account and asset, all good", %{conn: conn} do
    asset_title = "CERTIFICATE"

    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "PohTest",
        description: "PohTest",
        tx_type: "ProofOfHolding",
        tx_id: "",
        poh_asset: asset_title,
        poh_offer_asset: "COUPON20",
        poh_offer_token: "3",
        poh_token: "10"
      })

    wallet = ForgeSdk.create_wallet(moniker: "alice", commit: true)

    robert = WalletUtil.get_robert()
    {:ok, %{hash: hash}} = TxUtil.robert_offer(robert, wallet, 0, asset_title)
    %{tx: %{itx: %{assets: [asset]}}} = ForgeSdk.get_tx(hash: hash) |> ForgeSdk.display()

    # Step 1, wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.poh_path(conn, :start, tx.id))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.poh_url(@edpoint, :auth_principal, tx.id)

    assert [
             %{
               "type" => "authPrincipal",
               "description" => "Please set the authentication principal with minimal 10 token.",
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
    assert auth_body["url"] === Routes.poh_url(@edpoint, :return_asset, tx.id)

    assert [
             %{
               "description" => "Please return the address of a #{asset_title} owned by you.",
               "meta" => nil,
               "type" => "asset"
             }
           ] == auth_body["requestedClaims"]

    old_state = ForgeSdk.get_account_state(address: wallet.address)

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

    %{
      "status" => "ok",
      "response" => %{
        "hash" => hash,
        "tx" => tx
      }
    } = auth_body

    assert hash != nil
    assert tx != nil

    Process.sleep(3000)

    new_state = ForgeSdk.get_account_state(address: wallet.address)
    assert 1 + old_state.num_assets == new_state.num_assets

    assert 3 + ForgeAbi.unit_to_token(old_state.balance) ==
             ForgeAbi.unit_to_token(new_state.balance)
  end
end
