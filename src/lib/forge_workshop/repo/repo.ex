defmodule ForgeWorkshop.Repo do
  @moduledoc """
  Dispatch the Repo
  """

  require Logger

  def set_mod(mod) do
    if :ets.whereis(:forge_workshop) == :undefined do
      :ets.new(:forge_workshop, [:named_table])
    end

    :code.ensure_loaded(mod)
    :ets.insert(:forge_workshop, {:repo, mod})
  end

  def unquote(:"$handle_undefined_function")(func, args) do
    case :ets.lookup(:forge_workshop, :repo) do
      [{:repo, mod}] -> apply(mod, func, args)
      _ -> nil
    end
  rescue
    e -> Logger.warn("Failed with error: #{inspect(e)}")
  end
end
