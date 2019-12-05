defmodule ForgeWorkshopWeb.TestUtil do
  import ExUnit.Assertions
  import Phoenix.ConnTest

  alias ForgeWorkshop.{Demo, Tx, Util}
  alias ForgeWorkshopWeb.Router.Helpers, as: Routes

  @endpoint ForgeWorkshopWeb.Endpoint
  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def get_auth_body(auth_info) do
    auth_info
    |> String.split(".")
    |> Enum.at(1)
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  def assert_common_auth_info(pk, auth_body, demo) do
    assert pk === demo.pk

    assert %{
             "description" => demo.description,
             "name" => demo.name,
             "logo" => Routes.static_url(@endpoint, demo.icon),
             "link" => nil
           } == auth_body["appInfo"]

    assert auth_body["chainInfo"]["host"] == "http://localhost:8210/api/"
    assert auth_body["iss"] == "#{demo.did}"
    assert not is_nil(auth_body["exp"])
    assert not is_nil(auth_body["iat"])
    assert not is_nil(auth_body["nbf"])
  end

  def gen_signed_request(w, extra) do
    user_info = AbtDid.Signer.gen_and_sign(w.address, w.sk, extra)

    %{
      userPk: Multibase.encode!(w.pk, :base58_btc),
      userInfo: user_info
    }
  end

  def sign(wallet, digest) do
    bin = Util.str_to_bin(digest)
    %{key_type: key_type} = AbtDid.get_did_type(wallet.address)

    case key_type do
      :ed25519 -> Mcrypto.sign!(@ed25519, bin, wallet.sk)
      :secp256k1 -> Mcrypto.sign!(@secp256k1, bin, wallet.sk)
    end
    |> Multibase.encode!(:base58_btc)
  end

  def insert_tx(conn, tx) do
    demo = insert_demo()

    post(
      conn,
      Routes.tx_path(conn, :create),
      %{
        tx: Map.put(tx, :demo_id, demo.id)
      }
    )

    [transaction] = Tx.get_all(demo.id)
    {transaction, demo}
  end

  def insert_demo() do
    {pk, sk} = Mcrypto.keypair(%Mcrypto.Signer.Ed25519{})
    did_type = %AbtDid.Type{hash_type: :sha3, key_type: :ed25519, role_type: :application}
    did = AbtDid.sk_to_did(did_type, sk)

    {:ok, demo} =
      %{
        name: "Workshop Tests",
        subtitle: "Workshop Tests",
        description: "Workshop Tests",
        icon: "/images/logo@2x.png",
        path: "https://abtwallet.io/i/",
        sk: Multibase.encode!(sk, :base58_btc),
        pk: Multibase.encode!(pk, :base58_btc),
        did: did
      }
      |> Demo.insert()

    demo
  end
end
