defmodule AbtDidWorkshop.Util do
  @moduledoc false

  alias AbtDidWorkshop.{AppState, Demo, Repo, Util}
  alias AbtDidWorkshopWeb.Endpoint
  alias AbtDidWorkshopWeb.Router.Helpers, as: Routes

  def remote_chan do
    chan = config(:remote_chan)

    if chan !== nil and Process.alive?(chan.adapter_payload.conn_pid) do
      chan
    else
      remote_sock_grpc =
        config(["workshop", "remote_forge"])
        |> File.read!()
        |> Toml.decode!()
        |> get_in(["forge", "sock_grpc"])
        |> to_ip_and_port()

      {:ok, remote_chan} = GRPC.Stub.connect(remote_sock_grpc)
      Application.put_env(:abt_did_workshop, :remote_chan, remote_chan)
      Application.get_env(:abt_did_workshop, :remote_chan)
    end
  end

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

  def config([first | rest]), do: :abt_did_workshop |> Application.get_env(first) |> get_in(rest)
  def config(key), do: :abt_did_workshop |> Application.get_env(key)

  def get_port do
    case config([AbtDidWorkshopWeb.Endpoint, :http, :port]) do
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
      sock = Util.config([:forge_config, "sock_grpc"])
      ip_and_port = to_ip_and_port(sock)
      [ip, _] = split_ip_and_port(ip_and_port)
      web_port = Util.config([:forge_config, "web", "port"])
      Application.put_env(:abt_did_workshop, :local_forge_node, %{ip: ip, web_port: web_port})
    end

    forge_node = config(:local_forge_node)
    do_get_chainhost(forge_node)
  end

  def get_chainhost(:remote) do
    if config(:remote_forge_node) == nil do
      remote_forge = config(["workshop", "remote_forge"]) |> File.read!() |> Toml.decode!()
      sock = get_in(remote_forge, ["forge", "sock_grpc"])
      ip_and_port = to_ip_and_port(sock)
      [ip, _] = split_ip_and_port(ip_and_port)
      web_port = get_in(remote_forge, ["forge", "web", "port"])
      Application.put_env(:abt_did_workshop, :remote_forge_node, %{ip: ip, web_port: web_port})
    end

    forge_node = config(:remote_forge_node)
    do_get_chainhost(forge_node)
  end

  defp do_get_chainhost(%{ip: ip, web_port: port}) do
    "http://#{resolve_host(ip)}:#{port}/api/"
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
    gen_deeplink(app_state.path, app_state.pk, app_state.did, get_callback() <> "auth/")
  end

  def gen_deeplink(demo_id, tx_id) do
    demo = apply(Repo, :get, [Demo, demo_id])
    gen_deeplink(demo.path, demo.pk, demo.did, get_callback() <> "workflow/#{tx_id}")
  end

  def gen_deeplink(path, pk, did, url) do
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

  defp to_ip_and_port("tcp://" <> ip), do: ip
  defp to_ip_and_port("grpc://" <> ip), do: ip

  defp split_ip_and_port(value), do: String.split(value, ":")
end
