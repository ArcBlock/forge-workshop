defmodule AbtDidWorkshop.Tx.Poh do
  @moduledoc false

  alias AbtDidWorkshop.Tx.Helper

  def response_poh(beh, claims, user_addr) do
    if check_balance(beh.token, user_addr) == true do
      check_asset_title(beh.asset, claims, user_addr)
    else
      {:error, "Not enough balance."}
    end
  end

  defp check_asset_title(nil, _, _), do: :ok
  defp check_asset_title("", _, _), do: :ok

  defp check_asset_title(title, claims, user_addr) do
    Helper.extract_asset()
    |> Helper.get_claims(claims)
    |> case do
      [c] -> Helper.validate_asset(title, c["did"], user_addr)
      false -> {:error, "Need asset address."}
    end
  end

  defp check_balance(nil, _), do: true

  defp check_balance(token, user_addr) do
    case ForgeSdk.get_account_state(address: user_addr) do
      nil ->
        false

      state ->
        bal = ForgeAbi.Util.BigInt.to_int(state.balance)
        bal >= Helper.tba() * token
    end
  end
end
