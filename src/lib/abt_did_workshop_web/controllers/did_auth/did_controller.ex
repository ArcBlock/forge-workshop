defmodule AbtDidWorkshopWeb.DidController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType
  alias AbtDidWorkshop.AppState
  alias AbtDidWorkshop.UserDb
  alias AbtDidWorkshop.Tables.AppTable
  alias AbtDidWorkshop.AppAuthState

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    case AppTable.get() do
      nil -> render(conn, "step1.html")
      state -> render(conn, "index.html", did: state.did)
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

  def start_over(conn, _) do
    AppTable.delete()
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
    app_state = get_init_state()

    app_state =
      app_state
      |> Map.put(:sk, Multibase.encode!(sk, :base58_btc))
      |> Map.put(:pk, Multibase.encode!(pk, :base58_btc))
      |> Map.put(:did, did)

    changeset = AppAuthState.changeset(%AppAuthState{}, app_state)

    render(conn, "step2.html", changeset: changeset)
  end

  def upsert_app_state(conn, %{"app_auth_state" => state}) do
    # store_claims(params)
    # store_app_info(params)
    # AppState.add_path(path)

    # redirect(conn, to: "/did")

    case AppTable.insert(state) |> IO.inspect(label: "@@@") do
      {:ok, record} -> render(conn, "step3.html")
      {:error, changeset} -> render(conn, "step2.html", changeset: changeset)
    end
  end

  def store_claims(conn, params) do
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

  defp get_init_state do
    state = Application.get_env(:abt_did_workshop, :app_info) |> Enum.into(%{})
    path = Application.get_env(:abt_did_workshop, :deep_link_path)
    Map.put(state, :path, path)
  end
end
