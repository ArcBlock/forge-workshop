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

  def remove(did) do
    GenServer.call(__MODULE__, {:remove, did})
  end

  def get(did) do
    GenServer.call(__MODULE__, {:get, did})
  end

  def get_all() do
    GenServer.call(__MODULE__, {:get_all})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:add, user}, _from, state) do
    state = Map.put_new(state, user.did, user)
    {:reply, :ok, state}
  end

  def handle_call({:remove, did}, _from, state) do
    state = Map.delete(state, did)
    {:reply, :ok, state}
  end

  def handle_call({:get, did}, _from, state) do
    {:reply, Map.get(state, did), state}
  end

  def handle_call({:get_all}, _from, state) do
    {:reply, Map.values(state), state}
  end
end
