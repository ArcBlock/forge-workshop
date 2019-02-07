defmodule AbtDidWorkshop.AppState do
  @moduledoc """
  Store the information to generate challenge.
  """
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def add_key(sk, pk, did) do
    GenServer.call(__MODULE__, {:add_key, sk, pk, did})
  end

  def add_claims(claims) do
    GenServer.call(__MODULE__, {:add_claims, claims})
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:add_key, sk, pk, did}, _from, state) do
    state =
      state
      |> Map.put(:sk, sk)
      |> Map.put(:pk, pk)
      |> Map.put(:did, did)

    {:reply, :ok, state}
  end

  def handle_call({:add_claims, claims}, _from, state) do
    {:reply, :ok, Map.put(state, :claims, claims)}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end
