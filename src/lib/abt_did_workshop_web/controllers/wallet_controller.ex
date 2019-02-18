defmodule AbtDidWorkshopWeb.WalletController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.Util

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def request_auth(conn, %{"path" => "", "sk" => ""}) do
    conn
    |> put_flash(:error, "Invalid deep link or secret key")
    |> redirect(to: Routes.wallet_path(conn, :index))
    |> halt()
  end

  def request_auth(conn, %{"path" => path, "sk" => sk_str}) do
    sk = Util.str_to_bin(sk_str)

    url =
      path
      |> URI.parse()
      |> Map.get(:query)
      |> URI.decode_query()
      |> Map.get("url")

    pk = Mcrypto.sk_to_pk(%Mcrypto.Signer.Ed25519{}, sk)
    pk_str = Multibase.encode!(pk, :base58_btc)
    did_type = %AbtDid.Type{role_type: :account, key_type: :ed25519, hash_type: :sha3}
    did = AbtDid.pk_to_did(did_type, pk)

    %HTTPoison.Response{body: body} = HTTPoison.get!("#{url}?userDid=#{did}")
    do_request_auth(conn, body, {sk_str, pk_str, did, url})
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
      {:ok, %{"appPk" => _, "authInfo" => jwt}} ->
        render(conn, "authed.html", jwt: jwt, error: nil)

      _ ->
        render(conn, "authed.html", jwt: nil, error: response)
    end
  end
end
