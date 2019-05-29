defmodule AbtDidWorkshop.Step.RequireTether do
  @moduledoc """
  Requires deposited tether before doing exchange tether transaction.
  """
  use TypedStruct

  typedstruct do
    field(:desc, String.t(), enforce: true)
    # The asset title.
    field(:value, non_neg_integer(), enforce: true)
  end

  def new(desc, value) do
    %AbtDidWorkshop.Step.RequireTether{desc: desc, value: value}
  end
end
