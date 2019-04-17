defmodule AbtDidWorkshop.Repo do
  @moduledoc """
  Dispatch the Repo
  """

  require Logger

  def set_mod(mod) do
    if :ets.whereis(:abt_did_workshop) == :undefined do
      :ets.new(:abt_did_workshop, [:named_table])
    end

    :code.ensure_loaded(mod)
    :ets.insert(:abt_did_workshop, {:repo, mod})
  end

  def unquote(:"$handle_undefined_function")(func, args) do
    case :ets.lookup(:abt_did_workshop, :repo) do
      [{:repo, mod}] -> apply(mod, func, args)
      _ -> nil
    end
  rescue
    e -> Logger.warn("Failed with error: #{inspect(e)}")
  end
end
