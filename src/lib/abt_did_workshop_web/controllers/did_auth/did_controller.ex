defmodule AbtDidWorkshopWeb.DidController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType
  alias AbtDidWorkshop.AppState
  alias AbtDidWorkshop.UserDb

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    state = AppState.get()

    case Map.get(state, :did) do
      nil ->
        render(conn, "step1.html")

      _ ->
        render(conn, "index.html", did: state.did)
    end
  end

  def show(conn, _params) do
    app_state = AppState.get()

    cond do
      Map.get(app_state, :sk) == nil ->
        render(conn, "step1.html", alert: "You must create an application DID first.")

      Map.get(app_state, :path) == nil ->
        render(conn, "step2.html", alert: "Deep link path is required.")

      true ->
        render(conn, "show.html", sk: app_state.sk, users: AbtDidWorkshop.UserDb.get_all())
    end
  end

  def continue(conn, _) do
    app_state = AppState.get()

    case Map.get(app_state, :sk) do
      nil -> redirect(conn, to: "/")
      _ -> render(conn, "step2.html")
    end
  end

  def regenerate(conn, _) do
    AppState.clear()
    UserDb.clear()
    redirect(conn, to: "/")
  end

  def create_did(conn, params) do
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

    render(conn, "step2.html")
  end

  def update_claims(conn, %{"path" => path} = params) when path != "" do
    store_claims(params)
    store_app_info(params)
    AppState.add_path(path)

    redirect(conn, to: "/did")
  end

  def update_claims(conn, _) do
    conn
    |> put_flash(:error, "Invalid deep link or secret key")
    |> render("step2.html")
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

    AppState.add_profile(profile)

    agreements =
      claims
      |> Enum.filter(fn claim -> String.starts_with?(claim, "claim_agreement_") end)
      |> Enum.map(fn "claim_agreement_" <> claim -> claim end)

    AppState.add_agreements(agreements)
  end

  defp store_app_info(params) do
    params
    |> Map.to_list()
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, "app_info_") end)
    |> Enum.into(%{}, fn {"app_info_" <> k, v} -> {k, v} end)
    |> AppState.add_info()
  end
end
