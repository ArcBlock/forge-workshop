defmodule AbtDidWorkshop.Step.RequireAsset do
  @moduledoc """
  Represents a single step in a DID workflow.
  """
  use TypedStruct

  typedstruct do
    field(:desc, String.t(), enforce: true)
    # The asset title.
    field(:title, String.t(), enforce: true)
  end

  def new(desc, title) do
    %AbtDidWorkshop.Step.RequireAsset{desc: desc, title: title}
  end
end
