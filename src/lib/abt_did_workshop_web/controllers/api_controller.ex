defmodule AbtDidWorkshopWeb.ApiController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.Tx.Helper
  alias AbtDidWorkshop.Util

  def require_sig(
        conn,
        %{"tx" => tx_str, "url" => url, "description" => des, "workflow" => workflow} = param
      ) do
    wallet = get_wallet(param)
    tx_data = Multibase.decode!(tx_str)
    tx = ForgeAbi.Transaction.decode(tx_data)
    did_type = AbtDid.get_did_type(tx.from)
    digest = Helper.hash(did_type.hash_type, tx_data)

    claims = [
      %{
        type: "signature",
        meta: %{
          description: des
        },
        origin: Multibase.encode!(tx_data, :base58_btc),
        data: Multibase.encode!(digest, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]

    reply(conn, wallet, url, claims, workflow)
  end

  def require_sig(conn, _) do
    json(conn, %{error: "Insufficient data."})
  end

  def require_multi_sig(
        conn,
        %{"tx" => tx_str, "url" => url, "description" => des, "workflow" => workflow} = param
      ) do
    wallet = get_wallet(param)
    tx_data = Multibase.decode!(tx_str)
    tx = ForgeAbi.Transaction.decode(tx_data)
    [%{signer: signer}] = tx.signatures
    did_type = AbtDid.get_did_type(signer)
    digest = Helper.hash(did_type.hash_type, tx_data)

    claims = [
      %{
        type: "signature",
        meta: %{
          description: des
        },
        origin: Multibase.encode!(tx_data, :base58_btc),
        data: Multibase.encode!(digest, :base58_btc),
        method: did_type.hash_type,
        sig: ""
      }
    ]

    reply(conn, wallet, url, claims, workflow)
  end

  def require_multi_sig(conn, _) do
    json(conn, %{error: "Insufficient data."})
  end

  def require_asset(
        conn,
        %{"target" => target, "url" => url, "description" => des, "workflow" => workflow} = param
      ) do
    wallet = get_wallet(param)

    claims = [
      %{
        type: "did",
        meta: %{
          description: des
        },
        did_type: "asset",
        target: "#{target}",
        did: ""
      }
    ]

    reply(conn, wallet, url, claims, workflow)
  end

  def require_asset(conn, _) do
    json(conn, %{error: "Insufficient data."})
  end

  defp get_wallet(%{"sk" => sk, "pk" => pk, "address" => address}) do
    case sk do
      "" ->
        {robert, _} = AbtDidWorkshop.WalletUtil.init_robert()
        robert

      sk ->
        %{
          pk: Multibase.decode!(pk),
          sk: Multibase.decode!(sk),
          address: address
        }
    end
  end

  defp reply(conn, wallet, url, claims, workflow) do
    extra = %{
      url: url,
      appInfo: %{
        name: "Event Chain",
        subtitle: "A simple chain to host and join events.",
        description:
          "Event Chains lets you easily create and manage events, buy and sale evnet tickets.",
        icon: "http://did-workshop.arcblock.co:5000/static/images/eventchain.png",
        chainId: ForgeSdk.get_chain_info().network,
        chainHost: "http://#{Util.get_ip()}:8210/api",
        chainToken: "TBA",
        decimals: ForgeAbi.one_token() |> :math.log10() |> Kernel.trunc()
      },
      requestedClaims: claims,
      workflow: %{description: workflow}
    }

    response = %{
      appPk: wallet.pk |> Multibase.encode!(:base58_btc),
      authInfo: AbtDid.Signer.gen_and_sign(wallet.address, wallet.sk, extra)
    }

    json(conn, response)
  end
end
