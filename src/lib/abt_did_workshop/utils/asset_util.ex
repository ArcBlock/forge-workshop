defmodule AbtDidWorkshop.AssetUtil do
  @moduledoc false

  alias AbtDidWorkshop.Certificate

  alias ForgeAbi.{
    CreateAssetTx,
    ExchangeInfo,
    ExchangeTx,
    RequestGetAssets,
    RequestGetAssetState,
    RequestSendTx,
    RequestSignData,
    Transaction
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
    init_certs(owner, "ABT", 40)

    certs =
      [address: owner.address]
      |> ForgeSdk.get_assets()
      |> elem(0)
      |> Enum.filter(fn %{owner: addr} -> addr == owner.address end)

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

  def init_certs(wallet, title, number) do
    state = ForgeSdk.get_account_state(address: wallet.address)

    if state.num_assets < 20 do
      Task.async(fn ->
        for i <- 1..number do
          init_cert(wallet, title, i)
          Process.sleep(1000)
        end
      end)
    end
  end

  @doc """
  Creates a certificate under `wallet`
  """
  def init_cert(wallet, title, i) when is_number(i) do
    cert = gen_cert(wallet, "", title)
    create_cert(wallet, cert)
  end

  def init_cert(from, to, title) do
    cert = gen_cert(from, to, title)
    create_cert(from, cert)
  end

  defp create_cert(wallet, cert) do
    itx = CreateAssetTx.new(data: Any.new(type_url: "ws:x:certificate", value: cert))

    asset =
      ForgeSdk.get_asset_address(
        itx: itx,
        sender_address: wallet.address,
        wallet_type: wallet.type
      )

    nonce = ForgeSdk.get_nonce(wallet.address)

    tx =
      ForgeSdk.create_tx(
        from: wallet.address,
        itx: ForgeAbi.encode_any!(:create_asset, itx),
        nonce: nonce + 1,
        wallet: wallet
      )

    req = RequestSendTx.new(tx: tx, wallet: wallet, commit: false)

    case ForgeSdk.send_tx(req) do
      {:error, reason} -> {:error, reason}
      hash -> {hash, asset}
    end
  end

  def gen_cert(from, to, title, content \\ 0) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    nbf = exp = 0
    sig = sign_cert(from.sk, from.address, to, now, nbf, exp, title, content)

    Certificate.new(
      from: from.address,
      to: to,
      iat: now,
      exp: exp,
      title: title,
      content: content,
      sig: sig
    )
    |> Certificate.encode()
  end

  defp sign_cert(from_sk, from, to, iat, nbf, exp, title, content) do
    signer =
      case AbtDid.get_did_type(from).key_type do
        :ed25519 -> @ed25519
        :secp256k1 -> @secp256k1
      end

    data = "#{from}|#{to}|#{iat}|#{nbf}|#{exp}|#{title}|#{content}"

    Mcrypto.sign!(signer, data, from_sk)
  end
end
