defmodule ForgeWorkshop.Util do
  @moduledoc false

  alias ForgeWorkshop.{AppState, Demo, Repo}
  alias ForgeWorkshopWeb.Endpoint
  alias ForgeWorkshopWeb.Router.Helpers, as: Routes

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
      %{host: nil} -> Routes.static_url(conn, icon)
      _ -> icon
    end
  end

  def str_to_bin(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} -> bin
      _ -> Multibase.decode!(str)
    end
  end

  def get_ip do
    host = config([Endpoint, :url, :host])

    case host do
      h when h in [nil, "localhost", "127.0.0.1"] ->
        {:ok, ip_list} = :inet.getif()
        list = Enum.filter(ip_list, fn {_ip, broadcast, _netmask} -> broadcast != :undefined end)
        result = Enum.find(list, fn {ip, _, _} -> elem(ip, 0) == 192 or elem(ip, 0) == 10 end)

        {ip, _, _} =
          case result do
            nil -> List.first(list)
            _ -> result
          end

        {i1, i2, i3, i4} = ip
        "#{i1}.#{i2}.#{i3}.#{i4}"

      _ ->
        host
    end
  end

  def config([first | rest]), do: :forge_workshop |> Application.get_env(first) |> get_in(rest)
  def config(key), do: :forge_workshop |> Application.get_env(key)

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
    do_gen_deeplink(app_state.path, app_state.pk, app_state.did, get_callback() <> "auth/")
  end

  def gen_deeplink(demo_id, tx_id) do
    demo = apply(Repo, :get, [Demo, demo_id])
    gen_deeplink(demo.path, demo.pk, demo.did, tx_id)
  end

  def gen_deeplink(path, pk, did, tx_id) do
    url = get_callback() <> "workflow/#{tx_id}"
    do_gen_deeplink(path, pk, did, url)
  end

  defp do_gen_deeplink(path, pk, did, url) do
    path = String.trim_trailing(path, "/")

    pk =
      if String.valid?(pk) do
        pk
      else
        Multibase.encode!(pk, :base58_btc)
      end

    did =
      if String.starts_with?(did, "did:abt:") do
        did
      else
        "did:abt:" <> did
      end

    url = URI.encode_www_form(url)

    "#{path}?appPk=#{pk}&appDid=#{did}&action=requestAuth&url=#{url}"
  end

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
