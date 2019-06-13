defmodule ForgeWorkshopWeb.DidController do
  use ForgeWorkshopWeb, :controller

  alias AbtDid.Type, as: DidType
  alias ForgeWorkshop.{AppState, Repo, UserDb, Util}

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def index(conn, _params) do
    render(conn, "home.html")
  end

  def step1(conn, _params) do
    case AppState.get() do
      nil ->
        render(conn, "step1.html")

      state ->
        conn
        |> put_flash(:info, "Application already created!")
        |> render("show.html", app_state: state, users: UserDb.get_all())
    end
  end

  def show(conn, _params) do
    app_state = AppState.get()

    cond do
      app_state == nil ->
        conn
        |> put_flash(:error, "You must create an application DID first.")
        |> render("step1.html")

      Map.get(app_state, :name) == nil ->
        conn
        |> put_flash(:error, "Please configure meta data for application.")
        |> render("step2.html")

      true ->
        conn
        |> render("show.html", app_state: app_state, users: UserDb.get_all())
    end
  end

  def reselect_claims(conn, _) do
    app_state = AppState.get()

    case app_state do
      nil ->
        conn
        |> put_flash(:error, "You must create an application DID first.")
        |> render("step1.html")

      _ ->
        render(conn, "step3.html", id: app_state.id)
    end
  end

  def start_over(conn, _) do
    AppState.delete()
    UserDb.clear()

    conn
    |> put_flash(:info, "Application state was reset!")
    |> redirect(to: "/")
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

    changeset = AppState.changeset(%AppState{}, app_state)

    render(conn, "step2.html", changeset: changeset)
  end

  def upsert_app_state(conn, %{"app_state" => state}) do
    case AppState.insert(state) do
      {:ok, record} -> conn |> render("step3.html", id: record.id)
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

    changeset =
      Repo
      |> apply(:get!, [AppState, app_id])
      |> AppState.changeset(%{claims: %{profile: profile, agreements: agreements}})

    apply(Repo, :update!, [changeset])

    conn
    |> put_flash(:info, "Application succesfully updated!")
    |> redirect(to: Routes.did_path(conn, :show))
  end

  defp get_init_state do
    state = Util.config(:app_info)
    path = Util.config(:deep_link_path)
    Map.put(state, :path, path)
  end
end
