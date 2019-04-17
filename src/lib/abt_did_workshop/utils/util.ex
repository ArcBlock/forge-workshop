defmodule AbtDidWorkshop.Util do
  @moduledoc false

  alias AbtDidWorkshop.{AppState, Demo, Repo, Util}
  alias AbtDidWorkshopWeb.Router.Helpers, as: Routes

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
  end

  def config([first | rest]),
    do: :abt_did_workshop |> Application.get_env(first) |> get_in(rest)

  def config(key),
    do: :abt_did_workshop |> Application.get_env(key)

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
    if Application.get_env(:abt_did_workshop, :forge_node) == nil do
      host =
        ["forge", "sock_grpc"]
        |> Util.config()
        |> String.split("//")
        |> List.last()
        |> String.split(":")
        |> List.first()

      web_port = Util.config(["forge", "web", "port"])
      Application.put_env(:abt_did_workshop, :forge_node, %{host: host, web_port: web_port})
    end

    forge_node = Application.get_env(:abt_did_workshop, :forge_node)
    "http://#{forge_node.host}:#{forge_node.web_port}/api/"
  end

  def get_body(jwt) do
    jwt
    |> String.split(".")
    |> Enum.at(1)
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  def gen_deeplink(app_id) do
    app_state = Repo.get(AppState, app_id)
    gen_deeplink(app_state.path, app_state.pk, app_state.did, get_callback() <> "auth/")
  end

  def gen_deeplink(demo_id, tx_id) do
    demo = Repo.get(Demo, demo_id)
    gen_deeplink(demo.path, demo.pk, demo.did, get_callback() <> "workflow/#{tx_id}")
  end

  defp gen_deeplink(path, pk, did, url) do
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
end
