defmodule AbtDidWorkshopWeb.CertController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.AssetUtil
  alias AbtDidWorkshop.WalletUtil
  alias AbtDidWorkshop.Util

  alias ForgeAbi.Transaction

  def index(conn, _params) do
    text(conn, "123")
  end

  def recover_wallet(conn, _) do
    [{wallet, _}] = WalletUtil.init_wallets(1)

    json(conn, %{
      address: wallet.address,
      pk: Base.encode16(wallet.pk),
      sk: Base.encode16(wallet.sk),
      type: wallet.type
    })
  end

  @doc """
  Issue certificate to the `address`
  """
  def request_issue(conn, %{"userInfo" => user_info}) do
    address =
      user_info
      |> Util.get_body()
      |> Map.get("iss")

    if hasCert?(address) do
      json(conn, %{response: "You already have a certificate"})
    else
      {robert, _} = WalletUtil.init_robert()
      cert = AssetUtil.get_cert(robert)

      response =
        robert
        |> AssetUtil.give_away_cert(cert.address)
        |> Transaction.encode()
        |> Multibase.encode!(:base58_btc)
        |> request_sign(robert)

      json(conn, response)
    end
  end

  def response_issue(conn, %{"userInfo" => user_info}) do
    body = Util.get_body(user_info)
    address = Map.get(body, "iss")

    claim =
      body
      |> Map.get("requestedClaims")
      |> List.first()

    tx =
      claim
      |> Map.get("tx")
      |> Util.str_to_bin()
      |> Transaction.decode()

    sig =
      claim
      |> Map.get("sig")
      |> Util.str_to_bin()

    tx = %{tx | signatures: [AbciVendor.KVPair.new(key: address, value: sig)]}
    hash = ForgeSdk.send_tx(ForgeAbi.RequestSendTx.new(tx: tx))
    json(conn, %{tx: hash})
  end

  @doc """

  """
  # def reward(conn, %{"address" => address}) do
  #   if hasCert?(address) do
  #     json(conn, %{response: "ok"})
  #   else
  #     json(conn, %{response: "failed"})
  #   end
  # end

  def requeste_reward(conn, _param) do
    {robert, _} = WalletUtil.init_robert()
    json(conn, request_cert(robert))
  end

  def response_reward(conn, %{"userInfo" => user_info}) do
    body = Util.get_body(user_info)
    address = Map.get(body, "iss")

    asset =
      body
      |> Map.get("requestedClaims")
      |> List.first()
      |> Map.get("certificate")

    state = ForgeSdk.get_asset_state(address: asset) || %{owner: ""}

    if state.owner == address do
      json(conn, %{response: "ok"})
    else
      json(conn, %{response: "failed"})
    end
  end

  defp request_sign(tx, owner) do
    claims = [
      %{
        type: "proofOfHolding",
        meta: %{
          description: "Please sign the transaction."
        },
        tx: tx,
        sig: ""
      }
    ]

    callback = Util.get_callback() <> "cert/response-issue/"

    gen_and_sign(owner, %{
      url: callback,
      requestedClaims: claims
    })
  end

  defp hasCert?(address) do
    state = ForgeSdk.get_account_state(address: address) || %{num_assets: 0}
    state.num_assets > 0
  end

  defp request_cert(owner) do
    claims = [
      %{
        type: "proofOfHolding",
        meta: %{
          description: "Please provide your certification."
        },
        certificate: ""
      }
    ]

    callback = Util.get_callback() <> "cert/response-reward/"

    gen_and_sign(owner, %{
      url: callback,
      requestedClaims: claims
    })
  end

  defp gen_and_sign(owner, extra) do
    did_type = AbtDid.get_did_type(owner.address)
    auth_info = AbtDid.Signer.gen_and_sign(did_type, owner.sk, extra)

    %{
      appPk: owner.pk |> Multibase.encode!(:base58_btc),
      authInfo: auth_info
    }
  end
end
