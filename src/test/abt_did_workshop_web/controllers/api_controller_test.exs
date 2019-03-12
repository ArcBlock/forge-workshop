defmodule AbtDidWorkshopWeb.ApiControllerTest do
  use AbtDidWorkshopWeb.ConnCase

  alias AbtDidWorkshop.Util

  test "POST /api/requireMultiSig", %{conn: conn} do
    {sk1, pk1, did1} = get_keys()
    {sk2, pk2, did2} = get_keys()

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
        description: "dummy description"
      }
      |> Jason.encode!()

    conn = query(conn, "/api/requireMultiSig", body)
    response = Jason.decode!(conn.resp_body)
    assert response["appPk"] == Multibase.encode!(pk1, :base58_btc)
    auth_info = Util.get_body(response["authInfo"])
    assert auth_info["appInfo"] != nil
    assert auth_info["requestedClaims"] != nil
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
