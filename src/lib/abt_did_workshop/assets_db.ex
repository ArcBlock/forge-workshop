defmodule AbtDidWorkshop.AssetsDb do
  @moduledoc false

  use GenServer

  @folder_name ".abt_did_workshop"
  @file_name "assets"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def add(address) do
    GenServer.call(__MODULE__, {:add, address})
  end

  def member?(address) do
    GenServer.call(__MODULE__, {:member, address})
  end

  def init(:ok) do
    create_file()

    set =
      read_file()
      |> MapSet.new()

    {:ok, set}
  end

  def handle_call({:add, address}, _from, state) do
    write_file(address)
    {:reply, :ok, MapSet.put(state, address)}
  end

  def handle_call({:member, address}, _from, state) do
    {:reply, MapSet.member?(state, address), state}
  end

  defp create_file do
    home = System.user_home!()
    folder = Path.join(home, @folder_name)

    if File.exists?(folder) == false do
      File.mkdir(folder)
    end

    file = Path.join(folder, @file_name)

    if File.exists?(file) == false do
      File.touch!(file)
    end
  end

  defp read_file do
    home = System.user_home!()
    path = Path.join([home, @folder_name, @file_name])

    case File.read(path) do
      {:ok, content} -> content |> String.split("\n") |> Enum.reject(fn i -> i == "" end)
      _ -> []
    end
  end

  defp write_file(address) do
    home = System.user_home!()
    path = Path.join([home, @folder_name, @file_name])
    File.write(path, address <> "\n", [:append])
  end
end
