defmodule AbtDidWorkshop.UserDb do
  @moduledoc """
  A dummy DB to store registered user.
  """
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def add(user) do
    GenServer.call(__MODULE__, {:add, user})
  end

  def add_socket(socket) do
    GenServer.call(__MODULE__, {:add_socket, socket})
  end

  def remove(did) do
    GenServer.call(__MODULE__, {:remove, did})
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def get(did) do
    GenServer.call(__MODULE__, {:get, did})
  end

  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  def get_socket do
    GenServer.call(__MODULE__, :get_socket)
  end

  def init(:ok) do
    {:ok, {%{}, nil}}
  end

  def handle_call({:add, user}, _from, {db, socket}) do
    db = Map.put(db, user.did, user)
    {:reply, :ok, {db, socket}}
  end

  def handle_call({:add_socket, socket}, _from, {db, _}) do
    {:reply, :ok, {db, socket}}
  end

  def handle_call({:remove, did}, _from, {db, socket}) do
    db = Map.delete(db, did)
    {:reply, :ok, {db, socket}}
  end

  def handle_call(:clear, _from, {_, socket}) do
    {:reply, :ok, {%{}, socket}}
  end

  def handle_call({:get, did}, _from, {db, socket}) do
    {:reply, Map.get(db, did), {db, socket}}
  end

  def handle_call(:get_all, _from, {db, socket}) do
    {:reply, Map.values(db), {db, socket}}
  end

  def handle_call(:get_socket, _from, {db, socket}) do
    {:reply, socket, {db, socket}}
  end
end
