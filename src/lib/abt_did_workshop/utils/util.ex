defmodule AbtDidWorkshop.Util do
  @moduledoc false

  alias AbtDidWorkshop.{AppAuthState, Demo, Repo}

  def str_to_bin(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} -> bin
      _ -> Multibase.decode!(str)
    end
  end

  def get_ip do
    {:ok, ip_list} = :inet.getif()

    {ip, _broadcast, _netmask} =
      Enum.find(ip_list, fn {ip, broadcast, _netmask} ->
        ip != {127, 0, 0, 1} and broadcast != :undefined
      end)

    {i1, i2, i3, i4} = ip
    "#{i1}.#{i2}.#{i3}.#{i4}"
  end

  def get_port do
    :abt_did_workshop
    |> Application.get_env(AbtDidWorkshopWeb.Endpoint)
    |> Keyword.get(:http)
    |> Keyword.get(:port)
  end

  def get_callback do
    "http://#{get_ip()}:#{get_port()}/api/"
  end

  def get_agreement_uri(uri) do
    "http://#{get_ip()}:#{get_port()}" <> uri
  end

  def get_body(jwt) do
    jwt
    |> String.split(".")
    |> Enum.at(1)
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  def gen_deeplink(app_id) do
    app_state = Repo.get(AppAuthState, app_id)
    gen_deeplink(app_state.path, app_state.pk, app_state.did, get_callback() <> "auth/")
  end

  def gen_deeplink(demo_id, tx_id) do
    demo = Repo.get(Demo, demo_id)
    gen_deeplink(demo.path, demo.pk, demo.did, get_callback() <> "transaction/#{tx_id}")
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
