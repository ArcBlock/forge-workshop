defmodule AbtDidWorkshop.AppState do
  @moduledoc """
  Store the information to generate challenge.
  """
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def add_path(path) do
    GenServer.call(__MODULE__, {:add_path, path})
  end

  def add_key(sk, pk, did) do
    GenServer.call(__MODULE__, {:add_key, sk, pk, did})
  end

  def add_profile(claims) do
    GenServer.call(__MODULE__, {:add_profile, claims})
  end

  def add_agreements(claims) do
    GenServer.call(__MODULE__, {:add_agreements, claims})
  end

  def add_info(info) do
    GenServer.call(__MODULE__, {:add_info, info})
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def init(:ok) do
    app_info =
      :abt_did_workshop
      |> Application.get_env(:app_info, [])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    {:ok, %{info: app_info}}
  end

  def handle_call({:add_path, path}, _from, state) do
    {:reply, :ok, Map.put(state, :path, path)}
  end

  def handle_call({:add_key, sk, pk, did}, _from, state) do
    state =
      state
      |> Map.put(:sk, sk)
      |> Map.put(:pk, pk)
      |> Map.put(:did, did)

    {:reply, :ok, state}
  end

  def handle_call({:add_profile, claims}, _from, state) do
    {:reply, :ok, Map.put(state, :profile, claims)}
  end

  def handle_call({:add_agreements, claims}, _from, state) do
    {:reply, :ok, Map.put(state, :agreements, claims)}
  end

  def handle_call({:add_info, info}, _from, state) do
    {:reply, :ok, Map.put(state, :info, info)}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{info: state.info}}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end
