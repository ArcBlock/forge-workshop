defmodule Demo do
  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def request(w, tx_id, host \\ "localhost:4000")

  def request(w, :cert, host) do
    url = host <> "/api/cert/issue?userDid=#{w.address}"
    do_request(w, url)
  end

  def request(w, tx_id, host) do
    url = host <> "/api/transaction/#{tx_id}?userDid=#{w.address}"

    do_request(w, url)
  end

  defp do_request(w, url) when is_binary(url) do
    %HTTPoison.Response{body: response} = HTTPoison.get!(url)
    response = Jason.decode!(response)
    do_request(w, response)
  end

  defp do_request(_, %{"error" => error}) do
    error
  end

  defp do_request(w, %{"authInfo" => auth_info}) do
    info_body = get_body(auth_info)
    url = info_body["url"]
    claims = handle_claims(info_body["requestedClaims"], w)
    req = prepare_request(w, %{requestedClaims: claims})

    %HTTPoison.Response{body: body} =
      HTTPoison.post!(url, req, [{"Content-type", "application/json"}])

    Jason.decode!(body)
  end

  defp handle_claims(claims, wallet) do
    Enum.map(claims, &handle_claim(&1, wallet))
  end

  defp handle_claim(%{"type" => "signature", "tx" => tx_str} = claim, wallet) do
    tx_data = Multibase.decode!(tx_str)
    tx = ForgeAbi.Transaction.decode(tx_data)
    itx = ForgeAbi.decode_any(tx.itx)
    IO.inspect(tx)
    IO.inspect(itx)

    answer =
      IO.gets("Sign this transaction?\n") |> String.trim_trailing("\n") |> String.downcase()

    sig =
      case answer do
        "yes" -> ForgeSdk.Wallet.Util.sign!(wallet, tx_data)
        "y" -> ForgeSdk.Wallet.Util.sign!(wallet, tx_data)
      end

    Map.put(claim, "sig", sig |> Multibase.encode!(:base58_btc))
  end

  defp handle_claim(%{"type" => "signature"} = claim, wallet) do
    data = claim["data"] |> Multibase.decode!()
    tx = claim["origin"] |> Multibase.decode!() |> ForgeAbi.Transaction.decode()
    itx = ForgeAbi.decode_any(tx.itx)
    IO.inspect(tx)
    IO.inspect(itx)

    answer =
      IO.gets("Sign this transaction?\n") |> String.trim_trailing("\n") |> String.downcase()

    sig =
      case answer do
        "yes" -> sign(data, wallet)
        "y" -> sign(data, wallet)
      end

    Map.put(claim, "sig", sig)
  end

  defp handle_claim(%{"type" => "did"} = claim, _) do
    desc = claim["meta"]["description"]
    answer = IO.gets(desc <> "\n") |> String.trim_trailing("\n") |> String.downcase()
    Map.put(claim, "did", answer)
  end

  defp sign(data, wallet) do
    wallet.address
    |> AbtDid.get_did_type()
    |> Map.get(:key_type)
    |> sign(wallet.sk, data)
    |> Multibase.encode!(:base58_btc)
  end

  defp sign(:ed25519, sk, data), do: Mcrypto.sign!(@ed25519, data, sk)
  defp sign(:secp256k1, sk, data), do: Mcrypto.sign!(@secp256k1, data, sk)

  defp get_body(jwt) do
    jwt
    |> String.split(".")
    |> Enum.at(1)
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  defp prepare_request(w, extra) do
    user_info = AbtDid.Signer.gen_and_sign(w.address, w.sk, extra)

    %{
      userPk: Multibase.encode!(w.pk, :base58_btc),
      userInfo: user_info
    }
    |> Jason.encode!()
  end
end
