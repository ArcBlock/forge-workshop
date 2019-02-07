defmodule AbtDidWorkshopWeb.DidController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def create(conn, %{"hash_type" => hash_type, "key_type" => key_type}) do
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
    url = "http://#{get_ip()}/logon/"
    {jason, qr_code} = gen_qr_code(did, url)

    render(conn, "new.html", sk: sk, pk: pk, did: did, url: url, qr_code: qr_code, jason: jason)
  end

  defp get_ip do
    {:ok, ip_list} = :inet.getif()
    ips = List.first(ip_list)
    {i1, i2, i3, i4} = elem(ips, 0)
    "#{i1}.#{i2}.#{i3}.#{i4}"
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
end
