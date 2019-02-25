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
  def request_issue(conn, %{address: address}) do
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
        |> request_sign(cert.address, robert)

      json(conn, response)
    end
  end

  def response_issue(conn, %{address: address, sig: sig_str, tx: tx_str}) do
    tx =
      tx_str
      |> Util.str_to_bin()
      |> Transaction.decode()

    sig = Util.str_to_bin(sig_str)

    tx = %{tx | signatures: [AbciVendor.KVPair.new(key: address, value: sig)]}
    hash = ForgeSdk.send_tx(ForgeAbi.RequestSendTx.new(tx: tx))
    json(conn, %{tx: hash})
  end

  @doc """

  """
  def reward(conn, %{"address" => address}) do
    if hasCert?(address) do
      json(conn, %{response: "ok"})
    else
      json(conn, %{response: "failed"})
    end
  end

  defp request_sign(tx, asset, owner) do
    claims = [
      %{
        type: "proofOfHolding",
        meta: %{
          description: "Please sign the transaction."
        },
        tx: tx,
        asset: asset
      }
    ]

    callback = Util.get_callback() <> "cert/response-issue/"

    gen_and_sign(owner, %{
      url: callback,
      requestedClaims: claims
    })
  end

  defp hasCert?(address) do
    state = ForgeSdk.get_account_state(address: address)
    state.num_assets > 0
  end

  defp request_cert(owner) do
    claims = [
      %{
        type: "proofOfHolding",
        meta: %{
          description: "Please provide your certification."
        }
      }
    ]

    callback = Util.get_callback() <> "cert/response-reward/"

    gen_and_sign(owner, %{
      url: callback,
      requestedClaims: claims
    })
  end

  defp gen_and_sign(owner, extra \\ %{}) do
    did_type = AbtDid.get_did_type(owner.address)
    auth_info = AbtDid.Signer.gen_and_sign(did_type, owner.sk, extra)

    %{
      appPk: owner.pk |> Multibase.encode!(:base58_btc),
      authInfo: auth_info
    }
  end
end
