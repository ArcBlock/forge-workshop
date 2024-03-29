defmodule ForgeWorkshopWeb.DemoController do
  use ForgeWorkshopWeb, :controller

  alias ForgeWorkshop.{Demo, AppState, Repo, Util}

  def index(conn, _) do
    app_state = AppState.get()
    changeset = Demo.changeset(%Demo{}, %{})
    demos = Demo.get_all()
    render(conn, "index.html", demos: demos, app_state: app_state, changeset: changeset)
  end

  def new(conn, _) do
    app_state = AppState.get()
    changeset = Demo.changeset(%Demo{}, %{})
    render(conn, "new.html", app_state: app_state, changeset: changeset)
  end

  def create(conn, %{"demo" => demo}) do
    {pk, sk} = Mcrypto.keypair(%Mcrypto.Signer.Ed25519{})
    did_type = %AbtDid.Type{hash_type: :sha3, key_type: :ed25519, role_type: :application}
    did = AbtDid.sk_to_did(did_type, sk)

    demo =
      demo
      |> Map.put("sk", Multibase.encode!(sk, :base58_btc))
      |> Map.put("pk", Multibase.encode!(pk, :base58_btc))
      |> Map.put("did", did)
      |> Map.put("icon", get_icon(demo["icon"]))
      |> Map.put("path", get_path(demo["path"]))

    case Demo.insert(demo) do
      {:ok, record} ->
        conn
        |> put_flash(:info, "Successfully created application. Now please add transactions.")
        |> redirect(to: Routes.tx_path(conn, :index, demo_id: record.id))

      {:error, changeset} ->
        demos = Demo.get_all()
        render(conn, "index.html", demos: demos, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => demo_id}) do
    case Demo.delete(demo_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Successfully deleted application.")
        |> redirect(to: Routes.demo_path(conn, :index))

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.demo_path(conn, :index))
        |> halt()
    end
  end

  def edit(conn, %{"id" => demo_id}) do
    app_state = AppState.get()
    demo = apply(Repo, :get, [Demo, demo_id])
    changeset = Demo.changeset(demo)
    render(conn, "edit.html", changeset: changeset, demo: demo, app_state: app_state)
  end

  def update(conn, %{"id" => demo_id, "demo" => new_demo}) do
    old_demo = apply(Repo, :get, [Demo, demo_id])
    changeset = Demo.changeset(old_demo, new_demo)

    case apply(Repo, :update, [changeset]) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Application updated.")
        |> redirect(to: Routes.demo_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset, demo: old_demo)
    end
  end

  defp get_icon(""), do: Util.config([:app_info, :icon])
  defp get_icon(url), do: url

  defp get_path(""), do: Util.config(:deep_link_path)
  defp get_path(path), do: path
end
