defmodule ForgeWorkshop.Step.RequireDepositValue do
  @moduledoc """
  Requires deposit value before doing deposit tether transaction.
  """
  use TypedStruct

  typedstruct do
    field(:desc, String.t(), enforce: true)
  end

  def new(desc) do
    %ForgeWorkshop.Step.RequireDepositValue{desc: desc}
  end
end
