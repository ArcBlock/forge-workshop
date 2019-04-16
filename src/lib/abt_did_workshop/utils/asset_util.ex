defmodule AbtDidWorkshop.AssetUtil do
  @moduledoc false

  alias AbtDidWorkshop.WorkshopAsset
  alias ForgeAbi.{CreateAssetTx, RequestSendTx}

  require Logger

  @ed25519 %Mcrypto.Signer.Ed25519{}
  @secp256k1 %Mcrypto.Signer.Secp256k1{}

  def validate_asset(nil, _, _), do: :ok

  def validate_asset(title, asset_address, owner_address) do
    case ForgeSdk.get_asset_state(address: asset_address) do
      nil ->
        Logger.error("Could not find asset. Asset address: #{inspect(asset_address)}.")
        {:error, "Could not find asset. Asset address: #{inspect(asset_address)}."}

      {:error, reason} ->
        Logger.error(
          "Could not find asset. Reason: #{inspect(reason)}. Asset address: #{
            inspect(asset_address)
          }."
        )

        {:error, "Could not find asset. Asset address: #{inspect(asset_address)}."}

      state ->
        if Map.get(state, :owner) != owner_address do
          Logger.error(
            "The asset does not belong to the account. Asset address: #{inspect(asset_address)}. Owner address: #{
              inspect(owner_address)
            }"
          )

          {:error, "The asset does not belong to the account."}
        else
          case ForgeAbi.decode_any(state.data) do
            {:workshop_asset, cert} ->
              case cert.title do
                ^title ->
                  :ok

                _ ->
                  Logger.error(
                    "Incorrect workshop asset title. Expected: #{inspect(title)}, Actual: #{
                      inspect(cert.title)
                    }"
                  )

                  {:error, "Incorrect workshop asset title."}
              end

            _ ->
              Logger.error("Invalid asset. Asset address: #{inspect(asset_address)}")
              {:error, "Invalid asset."}
          end
        end
    end
  end

  def init_cert(from, to, title) do
    cert = gen_cert(from, to, title)
    create_cert(from, cert)
  end

  def gen_cert(from, to, title, content \\ 0) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    nbf = exp = 0
    sig = sign_cert(from.sk, from.address, to, now, nbf, exp, title, content)

    WorkshopAsset.new(
      from: from.address,
      to: to,
      iat: now,
      exp: exp,
      title: title,
      content: content,
      sig: sig
    )
  end

  defp create_cert(wallet, cert) do
    itx = CreateAssetTx.new(data: ForgeAbi.encode_any!(:workshop_asset, cert))

    asset =
      ForgeSdk.get_asset_address(
        itx: itx,
        sender_address: wallet.address,
        wallet_type: wallet.type
      )

    tx =
      ForgeSdk.create_tx(
        from: wallet.address,
        itx: ForgeAbi.encode_any!(:create_asset, itx),
        nonce: :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.to_integer(16),
        wallet: wallet
      )

    req = RequestSendTx.new(tx: tx, wallet: wallet, commit: true)

    case ForgeSdk.send_tx(req) do
      {:error, reason} -> {:error, reason}
      hash -> {hash, asset}
    end
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
