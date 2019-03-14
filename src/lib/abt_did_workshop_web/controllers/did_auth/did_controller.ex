defmodule AbtDidWorkshopWeb.DidController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType
  alias AbtDidWorkshop.UserDb
  alias AbtDidWorkshop.Tables.AppTable
  alias AbtDidWorkshop.AppAuthState
  alias AbtDidWorkshop.Repo

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    case AppTable.get() do
      nil -> render(conn, "step1.html")
      state -> render(conn, "index.html", did: state.did)
    end
  end

  def show(conn, _params) do
    app_state = AppTable.get()

    cond do
      app_state == nil ->
        render(conn, "step1.html", alert: "You must create an application DID first.")

      Map.get(app_state, :name) == nil ->
        render(conn, "step2.html", alert: "Please configure meta data for application.")

      true ->
        render(conn, "show.html", app_state: app_state, users: UserDb.get_all())
    end
  end

  def reselect_claims(conn, _) do
    app_state = AppTable.get()

    case app_state do
      nil -> render(conn, "step1.html", alert: "You must create an application DID first.")
      _ -> render(conn, "step3.html", id: app_state.id)
    end
  end

  def start_over(conn, _) do
    AppTable.delete()
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
    case AppTable.insert(state) do
      {:ok, record} -> render(conn, "step3.html", id: record.id)
      {:error, changeset} -> render(conn, "step2.html", changeset: changeset)
    end
  end

  def upsert_claims(conn, %{"id" => app_id} = params) do
    profile =
      params
      |> Enum.filter(fn {key, value} ->
        String.starts_with?(key, "profile_") and value == "true"
      end)
      |> Enum.map(fn {"profile_" <> claim, _} -> claim end)

    agreements =
      params
      |> Enum.filter(fn {key, value} ->
        String.starts_with?(key, "agreement_") and value == "true"
      end)
      |> Enum.map(fn {"agreement_" <> claim, _} -> claim end)

    AppAuthState
    |> Repo.get!(app_id)
    |> AppAuthState.changeset(%{claims: %{profile: profile, agreements: agreements}})
    |> Repo.update!()

    redirect(conn, to: Routes.did_path(conn, :show))
  end

  defp get_init_state do
    state = Application.get_env(:abt_did_workshop, :app_info) |> Enum.into(%{})
    path = Application.get_env(:abt_did_workshop, :deep_link_path)
    Map.put(state, :path, path)
  end
end
