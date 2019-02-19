defmodule AbtDidWorkshop.Util do
  @moduledoc false

  alias AbtDidWorkshop.AppState

  def get_ip do
    {:ok, ip_list} = :inet.getif()
    ips = List.first(ip_list)
    {i1, i2, i3, i4} = elem(ips, 0)
    "#{i1}.#{i2}.#{i3}.#{i4}"
  end

  def get_callback do
    port =
      :abt_did_workshop
      |> Application.get_env(AbtDidWorkshopWeb.Endpoint)
      |> Keyword.get(:http)
      |> Keyword.get(:port)

    "http://#{get_ip()}:#{port}/api/auth/"
  end

  def shorten(str, pre_len, post_len) do
    {pre, _} = String.split_at(str, pre_len - 1)
    {_, post} = String.split_at(str, String.length(str) - post_len)
    pre <> "..." <> post
  end

  def str_to_bin(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} -> bin
      _ -> Multibase.decode!(str)
    end
  end

  def get_body(jwt) do
    jwt
    |> String.split(".")
    |> Enum.at(1)
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end

  def gen_deeplink do
    url = get_callback() |> URI.encode_www_form()
    app_state = AppState.get()
    path = String.trim_trailing(app_state.path, "/")
    app_pk = Multibase.encode!(app_state.pk, :base58_btc)
    "#{path}?appPk=#{app_pk}&appDid=#{app_state.did}&action=requestAuth&url=#{url}"
  end

  def hex_to_bin("0x" <> hex), do: hex_to_bin(hex)
  def hex_to_bin(hex), do: Base.decode16!(hex, case: :mixed)
end
