defmodule AbtDidWorkshop.AssetUtil do
  alias AbtDidWorkshop.Certificate

  alias ForgeAbi.{
    CreateAssetTx,
    ExchangeInfo,
    ExchangeTx,
    Transaction,
    RequestGetAssets,
    RequestGetAssetState,
    RequestSendTx,
    RequestSignData
  }

  alias Google.Protobuf.Any

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def get_assets(wallet) do
    req = RequestGetAssets.new(owner_address: wallet.address)
    ForgeSdk.get_assets(req)
  end

  def get_asset_state(address) do
    RequestGetAssetState.new(address: address)
    |> ForgeSdk.get_asset_state()
  end

  def get_cert(owner) do
    certs =
      [address: owner.address]
      |> ForgeSdk.get_assets()
      |> elem(0)
      |> Enum.filter(fn %{owner: addr} -> addr == owner.address end)

    # if length(certs) < 5 do
    #   init_certs(owner, "ABT study certificate", 20)
    # end

    List.first(certs)
  end

  @doc """
  Prepares a transaction that give away the asset specified by `asset_address`.
  """
  def give_away_cert(owner, asset_address) do
    sender = ExchangeInfo.new(assets: [asset_address])
    itx = ExchangeTx.new(sender: sender, receiver: ExchangeInfo.new())
    ForgeSdk.exchange(itx, wallet: owner, send: :nosend)
  end

  def acquire_cert(acquirer, tx) do
    data = Transaction.encode(tx)
    req = RequestSignData.new(data: data, wallet: acquirer)
    sig = ForgeSdk.sign_data(req)
    tx = %{tx | signatures: [AbciVendor.KVPair.new(key: acquirer.address, value: sig)]}
    ForgeSdk.send_tx(ForgeAbi.RequestSendTx.new(tx: tx))
  end

  def init_certs(wallet, content, number) do
    for i <- 1..number do
      init_cert(wallet, content, i)
    end
  end

  @doc """
  Creates a certificate under `wallet`
  """
  def init_cert(wallet, content, i) do
    cert = gen_cert(wallet, content)
    itx = CreateAssetTx.new(data: Any.new(type_url: "ws:x:certificate", value: cert))
    nonce = ForgeSdk.get_nonce(wallet.address)

    tx =
      ForgeSdk.create_tx(
        from: wallet.address,
        itx: ForgeAbi.encode_any!(:create_asset, itx),
        nonce: nonce + i,
        wallet: wallet
      )

    # tx = ForgeSdk.create_asset(itx, send: :nosend, wallet: wallet, nonce: nonce)
    req = RequestSendTx.new(tx: tx, wallet: wallet, commit: false)
    ForgeSdk.send_tx(req)
  end

  defp gen_cert(w, content) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    exp = 0
    sig = sign_cert(w.sk, w.address, now, exp, content)

    Certificate.new(issuer: w.address, iat: now, exp: exp, content: content, sig: sig)
    |> Certificate.encode()
  end

  defp sign_cert(sk, addr, iat, exp, content) do
    signer =
      case AbtDid.get_did_type(addr).key_type do
        :ed25519 -> @ed25519
        :secp256k1 -> @secp256k1
      end

    data = "#{addr}|#{iat}|#{exp}|#{content}"

    Mcrypto.sign!(signer, data, sk)
  end
end
