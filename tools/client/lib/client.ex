defmodule Client do
  @moduledoc """
  Documentation for Client.
  """

  def get_wallet do
    %HTTPoison.Response{body: body} =
      HTTPoison.post!("localhost:4000/api/cert/recover-wallet", "")

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

  def request_issue(w) do
    %HTTPoison.Response{body: response} =
      HTTPoison.get!("localhost:4000/api/cert/issue?userDid=#{w.address}")

    response = Jason.decode!(response)
    auth_info = get_body(response["authInfo"])
    url = auth_info["url"]
    [claim] = auth_info["requestedClaims"]
    tx_data = str_to_bin(claim["tx"])
    sig = ForgeSdk.Wallet.Util.sign!(w, tx_data)

    claim = Map.put(claim, "sig", Multibase.encode!(sig, :base58_btc))
    user_info = AbtDid.Signer.gen_and_sign(w.address, w.sk, %{requestedClaims: [claim]})

    req =
      %{
        userPk: Multibase.encode!(w.pk, :base58_btc),
        userInfo: user_info
      }
      |> Jason.encode!()

    HTTPoison.post!(url, req, [{"content-type", "application/json"}])
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
end
