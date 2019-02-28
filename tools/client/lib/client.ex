defmodule Client do
  @moduledoc """
  Documentation for Client.
  """

  def get_wallet(host \\ "localhost:4000") do
    %HTTPoison.Response{body: body} = HTTPoison.post!(host <> "/api/cert/recover-wallet", "")

    w = Jason.decode!(body) |> IO.inspect()

    wt =
      w["type"]
      |> Enum.to_list()
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> ForgeAbi.WalletType.new()

    ForgeAbi.WalletInfo.new(
      address: w["address"],
      pk: str_to_bin(w["pk"]),
      sk: str_to_bin(w["sk"]),
      type: wt
    )
  end

  def get_cert(w, host \\ "localhost:4000") do
    %HTTPoison.Response{body: response} =
      HTTPoison.get!(host <> "/api/cert/issue?userDid=#{w.address}")

    response = Jason.decode!(response)
    do_get_cert(w, response)
  end

  defp do_get_cert(_, %{"error" => error}) do
    error
  end

  defp do_get_cert(w, response) do
    auth_info = get_body(response["authInfo"])
    url = auth_info["url"]
    [claim] = auth_info["requestedClaims"]
    tx_data = str_to_bin(claim["tx"])
    sig = ForgeSdk.Wallet.Util.sign!(w, tx_data)
    claim = Map.put(claim, "sig", Multibase.encode!(sig, :base58_btc))
    req = prepare_request(w, %{requestedClaims: [claim]})

    %HTTPoison.Response{body: body} =
      HTTPoison.post!(url, req, [{"content-type", "application/json"}])

    Jason.decode!(body)
  end

  def get_reward(w, asset, host \\ "localhost:4000") do
    # zjdgZ3VU2ojWUybnBUEkByZWShDhYJLUWKNm
    %HTTPoison.Response{body: response} = HTTPoison.get!(host <> "/api/cert/reward")
    response = Jason.decode!(response)
    auth_info = get_body(response["authInfo"])
    url = auth_info["url"]
    [claim] = auth_info["requestedClaims"]
    claim = Map.put(claim, "certificate", asset)
    req = prepare_request(w, %{requestedClaims: [claim]})

    %HTTPoison.Response{body: body} =
      HTTPoison.post!(url, req, [{"content-type", "application/json"}])

    Jason.decode!(body)
  end

  defp str_to_bin(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} -> bin
      _ -> Multibase.decode!(str)
    end
  end

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
