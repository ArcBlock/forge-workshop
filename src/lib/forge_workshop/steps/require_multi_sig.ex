defmodule ForgeWorkshop.Step.RequireMultiSig do
  @moduledoc """
  Represents a single step in a DID workflow.
  """
  use TypedStruct

  typedstruct do
    field(:desc, String.t(), enforce: true)
  end

  def new(desc) do
    %ForgeWorkshop.Step.RequireMultiSig{desc: desc}
  end
end
