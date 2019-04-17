defmodule AbtDidWorkshop.Step.RequireAccount do
  @moduledoc """
  Represents a single step in a DID workflow.
  """
  use TypedStruct

  typedstruct do
    field(:desc, String.t(), enforce: true)
    # The amount of token required if any.
    field(:token, non_neg_integer())
  end

  def new(desc, token \\ 0) do
    %AbtDidWorkshop.Step.RequireAccount{desc: desc, token: token}
  end
end
