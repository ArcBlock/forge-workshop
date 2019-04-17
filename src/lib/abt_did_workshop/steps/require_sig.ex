defmodule AbtDidWorkshop.Step.RequireSig do
  @moduledoc """
  Represents a single step in a DID workflow.
  """
  use TypedStruct

  typedstruct do
    field(:desc, String.t(), enforce: true)
  end

  def new(desc) do
    %AbtDidWorkshop.Step.RequireSig{desc: desc}
  end
end
