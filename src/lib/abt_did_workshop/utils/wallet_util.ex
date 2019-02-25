defmodule AbtDidWorkshop.WalletUtil do
  alias ForgeAbi.{
    EncodingType,
    DeclareTx,
    HashType,
    KeyType,
    RoleType,
    WalletInfo,
    WalletType,
    # Requests
    RequestCreateTx,
    RequestCreateWallet,
    RequestSendTx
  }

  def init_wallets(number) do
    moniker_prefix =
      :abt_did_workshop |> Application.get_env(:wallet) |> Keyword.get(:moniker_prefix)

    for i <- 1..number do
      {w, _} = create_wallet()
      tx_hash = declare_wallet(w, moniker_prefix <> "#{i}")
      {w, tx_hash}
    end
  end

  def create_wallet do
    passphrase = :abt_did_workshop |> Application.get_env(:wallet) |> Keyword.get(:passphrase)

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
    data = DeclareTx.new(moniker: moniker, pk: wallet.pk, type: wallet.type)
    itx = ForgeAbi.encode_any!(:declare, data)

    req_create =
      RequestCreateTx.new(from: wallet.address, itx: itx, nonce: 1, token: "", wallet: wallet)

    tx = ForgeSdk.create_tx(req_create)
    req_send = RequestSendTx.new(commit: false, token: "", tx: tx, wallet: wallet)
    ForgeSdk.send_tx(req_send)
  end

  def init_robert() do
    type =
      :abt_did_workshop |> Application.get_env(:robert) |> Keyword.get(:type) |> WalletType.new()

    [address: addr, pk: pk, sk: sk, type: _] = Application.get_env(:abt_did_workshop, :robert)
    w = WalletInfo.new(address: addr, pk: pk, sk: sk, type: type)

    hash = declare_wallet(w, "robert")
    {w, hash}
  end
end
