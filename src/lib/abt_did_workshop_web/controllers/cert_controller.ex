defmodule AbtDidWorkshopWeb.CertController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{AppState, AssetsDb, AssetUtil, Plugs.VerifySig, Util, WalletUtil}

  alias ForgeAbi.{Transaction, TransferTx, Util.BigInt}

  plug(VerifySig when action in [:response_issue, :response_reward])

  def recover_wallet(conn, _) do
    [{wallet, _}] = WalletUtil.init_wallets(1)

    json(conn, %{
      address: wallet.address,
      pk: Base.encode16(wallet.pk),
      sk: Base.encode16(wallet.sk),
      type: wallet.type
    })
  end

  def request_issue(conn, %{"userDid" => did}) do
    address = Util.did_to_address(did)

    if hasCert?(address) do
      json(conn, %{error: "You already have a certificate"})
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

  def response_issue(conn, _) do
    address = conn.assigns.did
    claim = List.first(conn.assigns.claims)

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

    case ForgeSdk.send_tx(ForgeAbi.RequestSendTx.new(tx: tx)) do
      {:error, reason} -> json(conn, %{error: reason})
      hash -> json(conn, %{tx: hash})
    end
  end

  def request_reward(conn, _param) do
    {robert, _} = WalletUtil.init_robert()
    json(conn, request_cert(robert))
  end

  def response_reward(conn, _) do
    address = conn.assigns.did

    asset =
      conn.assigns.claims
      |> List.first()
      |> Map.get("certificate")

    state = ForgeSdk.get_asset_state(address: asset) || %{owner: ""}

    if state.owner != address or AssetsDb.member?(asset) do
      json(conn, %{error: "Invalid certificate."})
    else
      AssetsDb.add(asset)
      {robert, _} = WalletUtil.init_robert()

      case transfer_token(robert, address) do
        {:error, reason} -> json(conn, %{error: reason})
        hash -> json(conn, %{tx: hash})
      end
    end
  end

  defp request_sign(tx, owner) do
    claims = [
      %{
        type: "signature",
        meta: %{
          description: "Please sign the transaction."
        },
        tx: tx,
        sig: ""
      }
    ]

    callback = Util.get_callback() <> "cert/issue/"

    gen_and_sign(owner, %{
      url: callback,
      requestedClaims: claims,
      appInfo: AppState.get().info
    })
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

    callback = Util.get_callback() <> "cert/reward/"

    gen_and_sign(owner, %{
      url: callback,
      requestedClaims: claims,
      appInfo: AppState.get().info
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

  defp hasCert?(address) do
    state = ForgeSdk.get_account_state(address: address) || %{num_assets: 0}
    state.num_assets > 0
  end

  defp transfer_token(from, to) do
    value = BigInt.biguint(1_000_000_000_000_000_000)
    itx = TransferTx.new(to: to, value: value)
    ForgeSdk.transfer(itx, wallet: from)
  end
end
