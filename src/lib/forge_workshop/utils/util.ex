defmodule ForgeWorkshop.Util do
  @moduledoc false

  alias ForgeWorkshop.{AppState, Demo, Repo, Tx}
  alias ForgeWorkshopWeb.Endpoint
  alias ForgeWorkshopWeb.Router.Helpers, as: Routes

  def hash(:keccak, data), do: Mcrypto.hash(%Mcrypto.Hasher.Keccak{}, data)
  def hash(:sha3, data), do: Mcrypto.hash(%Mcrypto.Hasher.Sha3{}, data)

  def to_token(%ForgeAbi.BigUint{} = value),
    do: value |> ForgeAbi.Util.BigInt.to_int() |> Kernel./(ForgeAbi.one_token())

  def to_token(number) when is_number(number),
    do: number / ForgeAbi.one_token()

  def local_chan do
    config(:local_chan)
  end

  def str_to_bin(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} -> bin
      _ -> Multibase.decode!(str)
    end
  end

  def config([first | rest]), do: :forge_workshop |> Application.get_env(first) |> get_in(rest)
  def config(key), do: :forge_workshop |> Application.get_env(key)

  def get_ip, do: config([Endpoint, :url, :host])

  def get_chainhost do
    config = ArcConfig.read_config(:forge_workshop)
    get_in(config, ["hyjal", "chain", "host"])
  end

  def get_body(jwt) do
    jwt
    |> String.split(".")
    |> Enum.at(1)
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  def gen_deeplink(app_id) do
    app_state = apply(Repo, :get, [AppState, app_id])
    url = Routes.auth_url(Endpoint, :start)
    do_gen_deeplink(app_state.path, url)
  end

  def gen_deeplink(demo_id, tx_id) do
    demo = apply(Repo, :get, [Demo, demo_id])
    url = get_workflow_entrace(tx_id)
    do_gen_deeplink(demo.path, url)
  end

  defp do_gen_deeplink(path, url) do
    path = String.trim_trailing(path, "/")
    url = URI.encode_www_form(url)
    "#{path}?action=requestAuth&url=#{url}"
  end

  def get_workflow_entrace(tx_id) do
    tx_id
    |> Tx.get()
    |> do_get_workflow_entrace()
  end

  defp do_get_workflow_entrace(%{tx_type: "PokeTx", id: id}),
    do: Routes.poke_url(Endpoint, :start, id)

  defp do_get_workflow_entrace(%{tx_type: "TransferTx", id: id}),
    do: Routes.transfer_url(Endpoint, :start, id)

  defp do_get_workflow_entrace(%{tx_type: "ExchangeTx", id: id}),
    do: Routes.exchange_url(Endpoint, :start, id)

  defp do_get_workflow_entrace(%{tx_type: "ConsumeAssetTx", id: id}),
    do: Routes.consume_asset_url(Endpoint, :start, id)

  defp do_get_workflow_entrace(%{tx_type: "UpdateAssetTx", id: id}),
    do: Routes.update_asset_url(Endpoint, :start, id)

  defp do_get_workflow_entrace(%{tx_type: "ProofOfHolding", id: id}),
    do: Routes.poh_url(Endpoint, :start, id)

  defp do_get_workflow_entrace(_), do: ""

  def hex_to_bin("0x" <> hex), do: hex_to_bin(hex)
  def hex_to_bin(hex), do: Base.decode16!(hex, case: :mixed)

  def did_to_address("did:abt:" <> address), do: address
  def did_to_address(address), do: address

  def empty?(nil), do: true
  def empty?(""), do: true
  def empty?(_), do: false
end
