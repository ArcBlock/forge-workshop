defmodule AbtDidWorkshop.WalletUtil do
  @moduledoc false

  alias ForgeAbi.{
    DeclareTx,
    EncodingType,
    HashType,
    KeyType,
    PokeTx,
    RequestCreateTx,
    RequestCreateWallet,
    RequestSendTx,
    RoleType,
    TransferTx,
    WalletInfo,
    WalletType
  }

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

  def init_wallets(number) do
    moniker_prefix = AbtDidWorkshop.Util.config([:wallet, :moniker_prefix])

    for i <- 1..number do
      {w, _} = create_wallet()
      tx_hash = declare_wallet(w, moniker_prefix <> "#{i}")
      {w, tx_hash}
    end
  end

  def create_wallet do
    passphrase = AbtDidWorkshop.Util.config([:wallet, :passphrase])

    type =
      WalletType.new(
        address: EncodingType.value(:base58),
        pk: KeyType.value(:ed25519),
        hash: HashType.value(:sha3),
        role: RoleType.value(:role_account)
      )

    req = RequestCreateWallet.new(moniker: "", passphrase: passphrase, type: type)
    ForgeSdk.create_wallet(req)
  end

  def declare_wallet(wallet, moniker) do
    data = apply(DeclareTx, :new, [[moniker: moniker, pk: wallet.pk, type: wallet.type]])
    itx = ForgeAbi.encode_any!(data, "fg:t:declare")

    req_create =
      RequestCreateTx.new(from: wallet.address, itx: itx, nonce: 1, token: "", wallet: wallet)

    tx = ForgeSdk.create_tx(req_create)
    req_send = RequestSendTx.new(commit: false, token: "", tx: tx, wallet: wallet)
    ForgeSdk.send_tx(req_send)
  end

  def poke(wallet) do
    %{address: address} = ForgeSdk.get_forge_state().poke_config

    itx =
      apply(PokeTx, :new, [
        [address: address, date: DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()]
      ])

    ForgeSdk.poke(itx, wallet: wallet)
  end

  def get_robert do
    %{address: addr, pk: pk, sk: sk} = AbtDidWorkshop.Util.config(:robert)
    state = ForgeSdk.get_account_state(address: addr)

    if state == nil or state.balance < ForgeAbi.token_to_unit(100) do
      init_robert()
    end

    WalletInfo.new(address: addr, pk: pk, sk: sk)
  end

  def init_robert do
    %{address: addr, pk: pk, sk: sk} = AbtDidWorkshop.Util.config(:robert)
    w = WalletInfo.new(address: addr, pk: pk, sk: sk)
    hash = declare_wallet(w, "robert")

    Task.async(fn ->
      wallets = init_wallets(100)
      Process.sleep(5_000)
      Enum.each(wallets, fn {w, _} -> poke(w) end)
      Process.sleep(5_000)

      %{amount: poke_amount} = ForgeSdk.get_forge_state().poke_config
      itx = apply(TransferTx, :new, [[to: addr, value: ForgeAbi.token_to_unit(poke_amount)]])

      Enum.each(wallets, fn {w, _} -> ForgeSdk.transfer(itx, wallet: w) end)
    end)

    {w, hash}
  end
end
