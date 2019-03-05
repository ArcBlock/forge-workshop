defmodule AbtDidWorkshopWeb.TransactionHelper do
  alias AbtDidWorkshop.{
    AssetUtil,
    Certificate
  }

  alias ForgeAbi.{
    ExchangeInfo,
    ExchangeTx,
    Transaction,
    TransferTx,
    UpdateAssetTx
  }

  @tba 1_000_000_000_000_000

  # The sender, receiver is a map with three keys:
  # sender.address
  # sender.asset -- Assets that sender should provide
  # sender.token -- Token that sender should provide.
  # receiver could have one more key `function`
  def get_transaction_to_sign(tx_type, sender, receiver) do
    itx = get_itx_to_sign(tx_type, sender, receiver)

    Transaction.new(
      chain_id: "forge-local",
      from: sender.address,
      itx: itx,
      nonce: ForgeSdk.get_nonce(sender.address) + 1
    )
  end

  def match?(expected, actual) do
    found =
      expected
      |> Enum.map(fn func -> Enum.find(actual, fn claim -> func.(claim) end) end)
      |> Enum.reject(&is_nil/1)

    if length(found) == length(expected) do
      found
    else
      false
    end
  end

  defp get_itx_to_sign("TransferTx", sender, receiver) do
    itx =
      TransferTx.new(
        assets: to_assets(sender.asset),
        to: receiver.address,
        value: to_tba(sender.token)
      )

    ForgeAbi.encode_any!(:transfer, itx)
  end

  defp get_itx_to_sign("ExchangeTx", sender, receiver) do
    s = ExchangeInfo.new(assets: to_assets(sender.asset), value: to_tba(sender.token))
    r = ExchangeInfo.new(assets: to_assets(receiver.asset), value: to_tba(receiver.token))
    itx = ExchangeTx.new(receiver: r, sender: s, to: receiver.address)
    ForgeAbi.encode_any!(:exchange, itx)
  end

  defp get_itx_to_sign("UpdateAssetTx", sender, receiver) do
    {_, cert} =
      case ForgeSdk.get_asset_state(address: sender.asset) do
        nil -> raise "Could not find asset #{sender.asset}."
        state -> ForgeAbi.decode_any(state.data)
      end

    {func, _} = Code.eval_string(receiver.function)
    new_content = func.(cert.content)
    new_cert = AssetUtil.gen_cert(receiver.address, sender.address, cert.title, new_content)
    itx = UpdateAssetTx.new(address: sender.asset, data: Certificate.encode(new_cert))
    ForgeAbi.encode_any!(:update_asset, itx)
  end

  # defp get_itx_to_sign("ActivateAssetTx", [beh], from, user_addr, [asset]) do
  # end

  defp to_tba(nil), do: nil

  defp to_tba(token) do
    ForgeAbi.Util.BigInt.biguint(token * @tba)
  end

  defp to_assets(nil), do: []
  defp to_assets(asset), do: [asset]
end
