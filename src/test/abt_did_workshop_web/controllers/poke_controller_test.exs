defmodule ForgeWorkshopWeb.PokeControllerTest do
  use ForgeWorkshopWeb.ConnCase

  alias ForgeWorkshopWeb.TestUtil

  @edpoint ForgeWorkshopWeb.Endpoint

  test "Poke, all good", %{conn: conn} do
    {tx, demo} =
      TestUtil.insert_tx(conn, %{
        name: "PokeTest",
        description: "PokeTest",
        tx_type: "PokeTx",
        tx_id: ""
      })

    wallet = ForgeSdk.create_wallet(moniker: "alice", commit: true)

    # Step 1, wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.poke_path(conn, :start, tx.id))
      |> json_response(200)

    auth_body = TestUtil.get_auth_body(auth_info)
    TestUtil.assert_common_auth_info(pk, auth_body, demo)
    assert auth_body["url"] === Routes.poke_url(@edpoint, :auth_principal, tx.id)

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
    assert auth_body["url"] === Routes.poke_url(@endpoint, :return_sig, tx.id)

    [
      %{
        "description" => "Please confirm this poke by signing the transaction.",
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
end
