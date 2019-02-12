defmodule AbtDidWorkshopWeb.DidController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType
  alias AbtDid.Jwt
  alias AbtDidWorkshop.AppState
  alias AbtDidWorkshop.Util

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    state = AppState.get()

    case Map.get(state, :did) do
      nil ->
        render(conn, "create.html", header: true)

      _ ->
        render(conn, "index.html", did: state.did)
    end
  end

  def show(conn, _) do
    state = AppState.get()
    url = Util.get_callback()
    {qr_code, body, head} = gen_qr_code(state.sk, state.pk, state.did, url)

    render(conn, "show.html",
      sk: state.sk,
      pk: state.pk,
      did: state.did,
      url: url,
      body: body,
      head: head,
      qr_code: qr_code
    )
  end

  def new(conn, _) do
    render(conn, "create.html")
  end

  def create(
        conn,
        %{"hash_type" => hash_type, "key_type" => key_type, "role_type" => role_type} = params
      ) do
    store_claims(params)

    {pk, sk} =
      case key_type do
        "ed25519" -> Mcrypto.keypair(@ed25519)
        "secp256k1" -> Mcrypto.keypair(@secp256k1)
      end

    did_type = %DidType{
      role_type: String.to_atom(role_type),
      key_type: String.to_atom(key_type),
      hash_type: String.to_atom(hash_type)
    }

    did = AbtDid.pk_to_did(did_type, pk)
    AppState.add_key(sk, pk, did)
    url = Util.get_callback()
    {qr_code, body, head} = gen_qr_code(sk, pk, did, url)

    render(conn, "show.html",
      sk: sk,
      pk: pk,
      did: did,
      url: url,
      body: body,
      head: head,
      qr_code: qr_code
    )
  end

  defp gen_qr_code(sk, pk, did, url) do
    did_type = AbtDid.get_did_type(did)
    challenge = Jwt.gen_and_sign(did_type, sk, %{"exp" => nil, "uri" => url})

    qrcode =
      %{
        app_pk: Multibase.encode!(pk, :base58_btc),
        challenge: challenge
      }
      |> Jason.encode!()

    [head, body, _] = String.split(challenge, ".")
    head = Base.url_decode64!(head, padding: false)
    body = Base.url_decode64!(body, padding: false)
    {qrcode, body, head}
  end

  defp store_claims(params) do
    params
    |> Map.to_list()
    |> Enum.filter(fn {key, value} -> String.starts_with?(key, "claim_") and "true" == value end)
    |> Enum.map(fn {key, _} -> key end)
    |> AbtDidWorkshop.AppState.add_claims()
  end
end
