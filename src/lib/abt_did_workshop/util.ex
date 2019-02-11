defmodule AbtDidWorkshop.Util do
  @moduledoc false
  def get_ip do
    {:ok, ip_list} = :inet.getif()
    ips = List.first(ip_list)
    {i1, i2, i3, i4} = elem(ips, 0)
    "#{i1}.#{i2}.#{i3}.#{i4}"
  end

  def get_callback do
    "http://#{get_ip()}/logon/"
  end
end
