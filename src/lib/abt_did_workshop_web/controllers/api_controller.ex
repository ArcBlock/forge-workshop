defmodule AbtDidWorkshopWeb.ApiController do
  use AbtDidWorkshopWeb, :controller

  def auth_info(conn, %{"sk" => sk, "pk" => pk, "address" => address, "tx" => tx, "url" => url}) do
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

    extra = %{
      url: url,
      requestedClaims: [
        %{
          type: "signature",
          meta: %{
            description: "Please sign the transaction."
          },
          tx: tx |> Base.decode64!() |> Multibase.encode!(:base58_btc),
          sig: ""
        }
      ],
      appInfo: %{
        name: "Event Chain",
        subtitle: "A simple chain to host and join events.",
        description:
          "Event Chains lets you easily create and manage events, buy and sale evnet tickets.",
        icon:
          "https://www.arcblock.io/static/d82a59b30376ad5f7b911d384fdd8fd9/dcd6f/1-new-website.jpg"
      }
    }

    response = %{
      appPk: wallet.pk |> Multibase.encode!(:base58_btc),
      authInfo: AbtDid.Signer.gen_and_sign(wallet.address, wallet.sk, extra)
    }

    json(conn, Jason.encode!(response))
  end
end
