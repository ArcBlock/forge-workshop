defmodule AbtDidWorkshopWeb.ApiController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.Tx.Helper

  def auth_info(conn, %{
        "sk" => sk,
        "pk" => pk,
        "address" => address,
        "tx" => tx_str,
        "url" => url
      }) do
    wallet =
      case sk do
        "" ->
          {robert, _} = AbtDidWorkshop.WalletUtil.init_robert()
          robert

        sk ->
          %{
            pk: Base.decode64!(pk),
            sk: Base.decode64!(sk),
            address: address
          }
      end

    tx_data = Base.decode64!(tx_str)
    tx = ForgeAbi.Transaction.decode(tx_data)
    did_type = AbtDid.get_did_type(tx.from)
    data = Helper.hash(did_type.hash_type, tx_data)

    extra = %{
      url: url,
      requestedClaims: [
        %{
          type: "signature",
          meta: %{
            description: "Please sign the transaction."
          },
          origin: Multibase.encode!(tx_data, :base58_btc),
          data: Multibase.encode!(data, :base58_btc),
          method: did_type.hash_type,
          sig: ""
        }
      ],
      appInfo: %{
        name: "Event Chain",
        subtitle: "A simple chain to host and join events.",
        description:
          "Event Chains lets you easily create and manage events, buy and sale evnet tickets.",
        icon: "http://did-workshop.arcblock.co:5000/static/images/eventchain.png"
      }
    }

    response = %{
      appPk: wallet.pk |> Multibase.encode!(:base58_btc),
      authInfo: AbtDid.Signer.gen_and_sign(wallet.address, wallet.sk, extra)
    }

    json(conn, Jason.encode!(response))
  end

  def auth_info(conn, _) do
    json(
      conn,
      Jason.encode!(%{error: "Insufficient data. You must have sk, pk, address, tx and url."})
    )
  end
end
