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
    qr_code = gen_qr_code(state.path, state.pk, state.did, url)

    render(conn, "show.html",
      sk: state.sk,
      pk: state.pk,
      did: state.did,
      url: url,
      qr_code: qr_code
    )
  end

  def new(conn, _) do
    render(conn, "create.html")
  end

  def create(conn, params) do
    store_claims(params)

    {pk, sk} =
      case params["key_type"] do
        "ed25519" -> Mcrypto.keypair(@ed25519)
        "secp256k1" -> Mcrypto.keypair(@secp256k1)
      end

    did_type = %DidType{
      role_type: String.to_atom(params["role_type"]),
      key_type: String.to_atom(params["key_type"]),
      hash_type: String.to_atom(params["hash_type"])
    }

    did = AbtDid.pk_to_did(did_type, pk)
    AppState.add_key(sk, pk, did)
    AppState.add_path(params["path"])
    url = Util.get_callback()
    qr_code = gen_qr_code(params["path"], pk, did, url)

    render(conn, "show.html",
      sk: sk,
      pk: pk,
      did: did,
      url: url,
      qr_code: qr_code
    )
  end

  defp gen_qr_code(path, pk, did, url) do
    path = String.trim_trailing(path, "/")
    app_pk = Multibase.encode!(pk, :base58_btc)
    url = URI.encode_www_form(url)
    "#{path}?app_pk=#{app_pk}&app_did=#{did}&action=request-auth&url=#{url}"
  end

  defp store_claims(params) do
    claims =
      params
      |> Map.to_list()
      |> Enum.filter(fn {key, value} -> String.starts_with?(key, "claim_") and "true" == value end)
      |> Enum.map(fn {key, _} -> key end)

    profile =
      claims
      |> Enum.filter(fn claim -> String.starts_with?(claim, "claim_profile_") end)
      |> Enum.map(fn "claim_profile_" <> claim -> claim end)

    AbtDidWorkshop.AppState.add_profile(profile)

    agreements =
      claims
      |> Enum.filter(fn claim -> String.starts_with?(claim, "claim_agreement_") end)
      |> Enum.map(fn "claim_agreement_" <> claim -> claim end)

    AbtDidWorkshop.AppState.add_agreements(agreements)
  end
end
