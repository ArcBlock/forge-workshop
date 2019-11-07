defmodule ForgeWorkshopWeb.WalletController do
  use ForgeWorkshopWeb, :controller

  alias ForgeWorkshop.{AppState, Util, WalletUtil}

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def create_wallet(conn, params) do
    cross_chain = Map.get(params, "cross_chain")
    wallet = WalletUtil.gen_wallet()

    WalletUtil.declare_wallet(wallet, "Awesome")

    if cross_chain != nil do
      WalletUtil.declare_wallet(wallet, "Awesome", "remote")
    end

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

    send_claims(conn, params["sk"], params["pk"], params["did"], url, %{
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

    %HTTPoison.Response{body: response} = HTTPoison.get!("#{url}")
    handle_response(conn, response, {sk_str, pk_str, did})
  rescue
    e ->
      stop(
        conn,
        "Authentication failed. Error message: #{Exception.message(e)}",
        Routes.wallet_path(conn, :index)
      )
  end

  defp handle_response(conn, response, user_info) do
    case Jason.decode!(response) do
      %{"appPk" => app_pk, "authInfo" => auth_info} ->
        pk = Util.str_to_bin(app_pk)
        do_handle_response(conn, pk, auth_info, user_info)

      _ ->
        conn
        |> put_flash(:error, response)
        |> redirect(to: Routes.wallet_path(conn, :index))
        |> halt()
    end
  end

  defp do_handle_response(conn, app_pk, auth_info, user_info) do
    if AbtDid.Signer.verify(auth_info, app_pk) do
      auth_body = Util.get_body(auth_info)
      handle_claim(conn, auth_body, user_info)
    else
      conn
      |> put_flash(:error, "The app pk and auth info do not match.")
      |> redirect(to: Routes.wallet_path(conn, :index))
      |> halt()
    end
  end

  defp handle_claim(
         conn,
         %{"requestedClaims" => [%{"type" => "authPrincipal"}]} = auth_body,
         {sk, pk, did}
       ) do
    url = auth_body["url"]
    send_claims(conn, sk, pk, did, url)
  end

  defp handle_claim(conn, %{"requestedClaims" => claims} = auth_body, {sk, pk, did}) do
    profile = Enum.find(claims, fn c -> c["type"] == "profile" end)
    agreements = Enum.filter(claims, fn c -> c["type"] == "agreement" end)
    app_info = Map.put(auth_body["appInfo"], "app_did", auth_body["iss"])
    url = auth_body["url"]

    render(conn, "claims.html",
      profile: profile,
      agreements: agreements,
      app_info: app_info,
      sk: sk,
      pk: pk,
      did: did,
      url: url
    )
  end

  defp handle_claim(conn, %{"status" => "ok"}, _) do
    conn
    |> put_flash(:info, "Authentication Succeeded!")
    |> redirect(to: Routes.did_path(conn, :show))
  end

  defp handle_claim(conn, %{"status" => "error"} = auth_body, _) do
    conn
    |> put_flash(:error, "Authentication failed! Error: #{auth_body["errorMessage"]}")
    |> redirect(to: Routes.did_path(conn, :show))
  end

  defp send_claims(conn, sk_str, pk, did, url, extra \\ %{}) do
    sk = Util.str_to_bin(sk_str)
    user_info = AbtDid.Signer.gen_and_sign(did, sk, extra)
    body = %{userPk: pk, userInfo: user_info} |> Jason.encode!()

    %HTTPoison.Response{body: response} =
      HTTPoison.post!(url, body, [{"content-type", "application/json"}])

    handle_response(conn, response, {sk_str, pk, did})
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

    digest = Util.str_to_bin(agreement.digest)
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
