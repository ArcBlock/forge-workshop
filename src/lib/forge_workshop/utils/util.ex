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

  def expand_icon_path(conn, icon) do
    icon =
      if icon == nil or icon == "" do
        config([:app_info, :icon])
      else
        icon
      end

    case URI.parse(icon) do
      %{host: nil} ->
        conn
        |> Routes.static_url(icon)
        |> URI.parse()
        |> Map.put(:host, get_ip())
        |> URI.to_string()

      _ ->
        icon
    end
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

  def get_port do
    case config([ForgeWorkshopWeb.Endpoint, :http, :port]) do
      {:system, "PORT"} -> System.get_env("PORT")
      port -> port
    end
  end

  def get_callback do
    "http://#{get_ip()}:#{get_port()}/api/"
  end

  def get_agreement_uri(uri) do
    "http://#{get_ip()}:#{get_port()}" <> uri
  end

  def get_chainhost do
    if config(:local_forge_node) == nil do
      sock = config(["workshop", "local_forge"])
      ip_and_port = to_ip_and_port(sock)
      [ip, _] = split_ip_and_port(ip_and_port)
      web_port = get_forge_web_port()
      Application.put_env(:forge_workshop, :local_forge_node, %{ip: ip, web_port: web_port})
    end

    forge_node = config(:local_forge_node)
    do_get_chainhost(forge_node)
  end

  def get_chainhost(:remote) do
    if config(:remote_forge_node) == nil do
      sock = config(["workshop", "remote_forge"])
      ip_and_port = to_ip_and_port(sock)
      [ip, _] = split_ip_and_port(ip_and_port)
      web_port = get_forge_web_port("remote")
      Application.put_env(:forge_workshop, :remote_forge_node, %{ip: ip, web_port: web_port})
    end

    forge_node = config(:remote_forge_node)
    do_get_chainhost(forge_node)
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
    do_gen_deeplink(app_state.path, get_callback() <> "auth/")
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

  defp resolve_host("127.0.0.1"), do: get_ip()
  defp resolve_host("localhost"), do: get_ip()
  defp resolve_host(host), do: host

  defp do_get_chainhost(%{ip: ip, web_port: port}) do
    "http://#{resolve_host(ip)}:#{port}/api/"
  end

  defp get_forge_web_port(conn_name \\ "") do
    [parsed: true]
    |> ForgeAbi.RequestGetConfig.new()
    |> ForgeSdk.get_config(conn_name)
    |> Jason.decode!()
    |> get_in(["forge", "web", "port"])
  end

  defp to_ip_and_port("tcp://" <> ip), do: ip
  defp to_ip_and_port("grpc://" <> ip), do: ip

  defp split_ip_and_port(value), do: String.split(value, ":")
end
