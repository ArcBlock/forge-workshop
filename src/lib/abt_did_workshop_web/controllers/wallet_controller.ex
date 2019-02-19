defmodule AbtDidWorkshopWeb.WalletController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.Util
  alias AbtDidWorkshop.AppState

  def index(conn, _params) do
    if Map.get(AppState.get(), :sk, nil) == nil do
      conn
      |> redirect(to: Routes.did_path(conn, :index))
    else
      keys = Application.get_env(:abt_did_workshop, :sample_keys, [])
      render(conn, "index.html", keys: keys)
    end
  end

  def request_auth(conn, params) do
    cond do
      Map.get(params, "path", "") == "" ->
        stop(conn, "Invalid deep link.", Routes.wallet_path(conn, :index))

      Map.get(params, "sample_key") == "Choose your key" and
          Map.get(params, "input_key", "") == "" ->
        stop(conn, "Please provide a secret key.", Routes.wallet_path(conn, :index))

      Map.get(params, "sample_key") != "Choose your key" and
          Map.get(params, "input_key", "") != "" ->
        stop(conn, "Please provide one secret key at a time.", Routes.wallet_path(conn, :index))

      Map.get(params, "sample_key") != "Choose your key" ->
        do_request_auth(conn, Map.put(params, "sk", Map.get(params, "sample_key")))

      Map.get(params, "input_key") != "" ->
        do_request_auth(conn, Map.put(params, "sk", Map.get(params, "input_key")))
    end
  end

  def response_auth(conn, params) do
    profile =
      params
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, "profile_") end)
      |> Enum.into(%{type: "profile"}, fn {"profile_" <> key, value} -> {key, value} end)

    url = URI.decode_www_form(params["url"])

    do_response_auth(conn, params["sk"], params["pk"], params["did"], url, %{
      requestedClaims: [profile]
    })
  end

  defp do_request_auth(conn, %{"path" => path, "sk" => sk_str}) do
    url =
      path
      |> URI.parse()
      |> Map.get(:query)
      |> URI.decode_query()
      |> Map.get("url")

    sk = Util.str_to_bin(sk_str)

    {signer, key_type} =
      case byte_size(sk) do
        64 -> {%Mcrypto.Signer.Ed25519{}, :ed25519}
        32 -> {%Mcrypto.Signer.Secp256k1{}, :secp256k1}
        _ -> raise "Invalid secret key size."
      end

    pk = Mcrypto.sk_to_pk(signer, sk)
    pk_str = Multibase.encode!(pk, :base58_btc)
    did_type = %AbtDid.Type{role_type: :account, key_type: key_type, hash_type: :sha3}
    did = AbtDid.pk_to_did(did_type, pk)

    %HTTPoison.Response{body: body} = HTTPoison.get!("#{url}?userDid=#{did}")
    do_request_auth(conn, body, {sk_str, pk_str, did, url})
  rescue
    e ->
      stop(
        conn,
        "Authentication failed. Error message: #{Exception.message(e)}",
        Routes.wallet_path(conn, :index)
      )
  end

  defp do_request_auth(conn, body, user_info) do
    case Jason.decode!(body) do
      %{"appPk" => app_pk, "authInfo" => auth_info} ->
        pk = Util.str_to_bin(app_pk)
        do_request_auth(conn, pk, auth_info, user_info)

      _ ->
        conn
        |> put_flash(:error, body)
        |> redirect(to: Routes.wallet_path(conn, :index))
        |> halt()
    end
  end

  defp do_request_auth(conn, app_pk, auth_info, {sk, pk, did, url}) do
    if AbtDid.Signer.verify(auth_info, app_pk) do
      body = Util.get_body(auth_info)

      case Map.get(body, "requestedClaims", []) do
        [] ->
          do_response_auth(conn, sk, pk, did, url)

        claims ->
          profile =
            Enum.filter(claims, fn claim -> claim["type"] == "profile" end) |> List.first()

          agreements = Enum.filter(claims, fn claim -> claim["type"] == "agreement" end)

          render(conn, "claims.html",
            profile: profile,
            agreements: agreements,
            sk: sk,
            pk: pk,
            did: did,
            url: URI.encode_www_form(url)
          )
      end
    else
      conn
      |> put_flash(:error, "The app pk and auth info do not match.")
      |> redirect(to: Routes.wallet_path(conn, :index))
      |> halt()
    end
  end

  defp do_response_auth(conn, sk_str, pk, did, url, extra \\ %{}) do
    sk = Util.str_to_bin(sk_str)
    user_info = AbtDid.Signer.gen_and_sign(did, sk, extra)
    body = %{userPk: pk, userInfo: user_info} |> Jason.encode!()

    %HTTPoison.Response{body: response} =
      HTTPoison.post!(url, body, [{"content-type", "application/json"}])

    case Jason.decode(response) do
      {:ok, %{"appPk" => _}} ->
        render(conn, "authed.html", error: nil)

      _ ->
        render(conn, "authed.html", error: response)
    end
  end

  defp stop(conn, error, to) do
    conn
    |> put_flash(:error, error)
    |> redirect(to: to)
    |> halt()
  end
end
