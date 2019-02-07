defmodule AbtDidWorkshopWeb.DidController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType
  alias AbtDidWorkshop.Util

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def create(conn, %{"hash_type" => hash_type, "key_type" => key_type} = params) do
    store_claims(params)

    {pk, sk} =
      case key_type do
        "ed25519" -> Mcrypto.keypair(@ed25519)
        "secp256k1" -> Mcrypto.keypair(@secp256k1)
      end

    did_type = %DidType{
      role_type: :application,
      key_type: String.to_atom(key_type),
      hash_type: String.to_atom(hash_type)
    }

    did = AbtDid.pk_to_did(did_type, pk)
    AbtDidWorkshop.AppState.add_key(sk, pk, did)
    url = Util.get_callback()
    {jason, qr_code} = gen_qr_code(did, url)

    render(conn, "new.html", sk: sk, pk: pk, did: did, url: url, qr_code: qr_code, jason: jason)
  end

  defp gen_qr_code(did, url) do
    jason =
      %{
        app_did: did,
        callback: url
      }
      |> Jason.encode!()

    qr_code =
      jason
      |> EQRCode.encode()
      |> EQRCode.svg()

    {jason, qr_code}
  end

  defp store_claims(params) do
    params
    |> Map.to_list()
    |> Enum.filter(fn {key, value} -> String.starts_with?(key, "claim_") and "true" == value end)
    |> Enum.map(fn {key, _} -> key end)
    |> AbtDidWorkshop.AppState.add_claims()
  end
end
