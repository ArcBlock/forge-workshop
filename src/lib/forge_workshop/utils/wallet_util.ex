defmodule ForgeWorkshop.WalletUtil do
  @moduledoc false

  alias ForgeAbi.{DeclareTx, PokeTx, TransferTx, WalletInfo}

  def check_balance(token, _) when token in [nil, 0], do: true

  def check_balance(token, user_addr) do
    case ForgeSdk.get_account_state(address: user_addr) do
      nil ->
        false

      state ->
        state.balance >= ForgeAbi.token_to_unit(token)
    end
  end

  def get_account_state(address) do
    state = ForgeSdk.get_account_state(address: address)

    case state do
      nil ->
        nil

      state ->
        %{balance: ForgeAbi.Util.BigInt.to_int(state.balance), num_assets: state.num_assets}
    end
  end

  def init_wallets(number, chan \\ "") do
    moniker_prefix = ForgeWorkshop.Util.config([:wallet, :moniker_prefix])

    for i <- 1..number do
      w = create_wallet(chan)
      tx_hash = declare_wallet(w, moniker_prefix <> "#{i}", chan)
      {w, tx_hash}
    end
  end

  def create_wallet(_chan \\ "") do
    ForgeSdk.create_wallet(send: :nosend)
  end

  def declare_wallet(wallet, moniker, _chan \\ "") do
    itx = apply(DeclareTx, :new, [[moniker: moniker]])
    ForgeSdk.declare(itx, wallet: wallet)
  end

  @doc """
  Generates a wallet without talke to chain.
  """
  def gen_wallet(
        did_type \\ %AbtDid.Type{role_type: :account, key_type: :ed25519, hash_type: :sha3}
      ) do
    {pk, sk} = gen_key_pair(did_type.key_type)
    address = AbtDid.pk_to_did(did_type, pk, form: :short)
    ForgeAbi.WalletInfo.new(address: address, pk: pk, sk: sk)
  end

  def poke(wallet, chan \\ "") do
    %{address: address} =
      chan
      |> ForgeSdk.get_forge_state()
      |> Map.from_struct()
      |> get_in([:account_config, "token_holder"])

    itx =
      apply(PokeTx, :new, [
        [address: address, date: DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()]
      ])

    ForgeSdk.poke(itx, wallet: wallet, conn: chan)
  end

  def get_robert do
    %{address: addr, pk: pk, sk: sk} = ForgeWorkshop.Util.config(:robert)
    state = ForgeSdk.get_account_state(address: addr)

    if state == nil or state.balance < ForgeAbi.token_to_unit(100) do
      init_robert()
    end

    WalletInfo.new(address: addr, pk: pk, sk: sk)
  end

  def init_robert do
    %{address: addr, pk: pk, sk: sk} = ForgeWorkshop.Util.config(:robert)
    w = WalletInfo.new(address: addr, pk: pk, sk: sk)
    hash = declare_wallet(w, "robert")
    raise_balance(w.address, 100)
    {w, hash}
  end

  def raise_balance(address, number, chan \\ "") do
    Task.async(fn ->
      wallets = init_wallets(number, chan)
      Process.sleep(number * 50)
      Enum.each(wallets, fn {w, _} -> poke(w, chan) end)
      Process.sleep(number * 50)
      %{tx_config: %{poke: %{amount: poke_amount}}} = ForgeSdk.get_forge_state(chan)
      itx = apply(TransferTx, :new, [[to: address, value: ForgeAbi.token_to_unit(poke_amount)]])
      Enum.each(wallets, fn {w, _} -> ForgeSdk.transfer(itx, wallet: w, conn: chan) end)
    end)
  end

  defp gen_key_pair(:ed25519) do
    Mcrypto.keypair(%Mcrypto.Signer.Ed25519{})
  end

  defp gen_key_pair(:secp256k1) do
    Mcrypto.keypair(%Mcrypto.Signer.Secp256k1{})
  end
end
