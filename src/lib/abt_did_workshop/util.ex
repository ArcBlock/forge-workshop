defmodule AbtDidWorkshop.Util do
  @moduledoc false
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

    "http://#{get_ip()}:#{port}/api/logon/"
  end

  def shorten(str, pre_len, post_len) do
    {pre, _} = String.split_at(str, pre_len - 1)
    {_, post} = String.split_at(str, String.length(str) - post_len)
    pre <> "..." <> post
  end
end
