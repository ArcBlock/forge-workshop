defmodule AbtDidWorkshopWeb.ApiControllerTest do
  use AbtDidWorkshopWeb.ConnCase

  import Mock

  alias AbtDidWorkshop.Util

  test "POST /api/requireMultiSig", %{conn: conn} do
    {sk1, pk1, did1} = get_keys()
    {_sk2, _pk2, did2} = get_keys()

    tx =
      ForgeAbi.Transaction.new(
        chain_id: "forge-local",
        from: did1,
        itx: ForgeAbi.encode_any!(:consume_asset, ForgeAbi.ConsumeAssetTx.new(issuer: did1)),
        nonce: 1,
        signatures: [
          ForgeAbi.Multisig.new(
            data: ForgeAbi.encode_any!(:address, "zjdzJUXgVPJurBz3EQMrkBVtXkWnVJYyC4mY"),
            signer: did2
          )
        ]
      )

    tx_str = tx |> ForgeAbi.Transaction.encode() |> Multibase.encode!(:base58_btc)

    body =
      %{
        url: "dummy_url.com",
        tx: tx_str,
        pk: Multibase.encode!(pk1, :base58_btc),
        sk: Multibase.encode!(sk1, :base58_btc),
        address: did1,
        description: "dummy description",
        workflow: "dummy workflow"
      }
      |> Jason.encode!()

    with_mocks([
      {ForgeSdk, [], [get_chain_info: fn -> %{network: "forge-dummy"} end]},
      {ForgeAbi, [], [one_token: fn -> 10 end]}
    ]) do
      conn = query(conn, "/api/requireMultiSig", body)
      response = Jason.decode!(conn.resp_body)
      assert response["appPk"] == Multibase.encode!(pk1, :base58_btc)
      auth_info = Util.get_body(response["authInfo"])
      assert auth_info["requestedClaims"] != nil
      assert auth_info["workflow"] == %{"description" => "dummy workflow"}
      app_info = auth_info["appInfo"]
      assert app_info != nil
      assert app_info["chainId"] == "forge-dummy"
      assert String.ends_with?(app_info["chainHost"], ":8210/api")
      assert app_info["chainToken"] == "TBA"
      assert app_info["decimals"] == 1
    end
  end

  defp query(conn, url, data) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(url, data)
  end

  defp get_keys() do
    {pk, sk} = Mcrypto.keypair(%Mcrypto.Signer.Ed25519{})
    did = AbtDid.sk_to_did(%AbtDid.Type{}, sk)
    {sk, pk, did}
  end
end
