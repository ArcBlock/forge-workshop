defmodule AbtDidWorkshopWeb.WalletController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{AppState, Util, WalletUtil}

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def create_wallet(conn, _) do
    [{wallet, _}] = WalletUtil.init_wallets(1)

    json(conn, %{
      address: wallet.address,
      pk: Base.encode16(wallet.pk),
      sk: Base.encode16(wallet.sk),
      type: wallet.type
    })
  end

  def wallet_state(conn, %{"addr" => addr}) do
    account = WalletUtil.get_account_state(addr)
    {assets, _} = ForgeSdk.list_assets(owner_address: addr)

    certs =
      Enum.into(assets, %{}, fn asset ->
        {_, cert} =
          [address: asset.address]
          |> ForgeSdk.get_asset_state()
          |> Map.get(:data)
          |> ForgeAbi.decode_any()

        {asset.address, [cert.title, cert.content]}
      end)

    json(conn, Map.put(account, :assets, certs))
  end

  def index(conn, _params) do
    case AppState.get() do
      nil ->
        redirect(conn, to: Routes.did_path(conn, :index))

      app_state ->
        keys = Util.config(:sample_keys)
        render(conn, "index.html", keys: keys, app_state: app_state)
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

    agreements = process_agreements(params)
    url = URI.decode_www_form(params["url"])

    do_response_auth(conn, params["sk"], params["pk"], params["did"], url, %{
      requestedClaims: [profile] ++ agreements
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

      case Map.get(body, "requestedClaims") || [] do
        [] ->
          do_response_auth(conn, sk, pk, did, url)

        claims ->
          profile = claims |> Enum.filter(fn c -> c["type"] == "profile" end) |> List.first()
          agreements = Enum.filter(claims, fn c -> c["type"] == "agreement" end)
          app_info = Map.get(body, "appInfo", %{})

          render(conn, "claims.html",
            profile: profile,
            agreements: agreements,
            app_info: app_info,
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
      {:ok, %{"response" => _}} ->
        conn
        |> put_flash(:info, "Authentication Succeeded!")
        |> redirect(to: Routes.did_path(conn, :show))

      _ ->
        conn
        |> put_flash(:error, "Authentication failed! Error: #{response}")
        |> redirect(to: Routes.did_path(conn, :show))
    end
  end

  defp process_agreements(params) do
    result =
      params
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, "agreement_") end)
      |> Enum.into(%{}, fn
        {"agreement_" <> id, "true"} -> {id, true}
        {"agreement_" <> id, "false"} -> {id, false}
      end)

    :agreement
    |> Util.config()
    |> Enum.map(fn agr ->
      agr
      |> Map.delete(:content)
      |> Map.put(:agreed, result[agr.meta.id])
      |> Map.delete(:meta)
    end)
    |> Enum.map(fn agr ->
      case agr.agreed do
        true -> sign_agreement(agr, params["sk"], params["did"])
        _ -> agr
      end
    end)
  end

  defp sign_agreement(agreement, sk_str, did) do
    did_type = AbtDid.get_did_type(did)

    signer =
      case did_type.key_type do
        :ed25519 -> @ed25519
        :secp256k1 -> @secp256k1
      end

    digest = Util.str_to_bin(agreement.hash.digest)
    sk = Util.str_to_bin(sk_str)
    sig = Mcrypto.sign!(signer, digest, sk) |> Multibase.encode!(:base58_btc)
    Map.put(agreement, :sig, sig)
  end

  defp stop(conn, error, to) do
    conn
    |> put_flash(:error, error)
    |> redirect(to: to)
    |> halt()
  end
end
