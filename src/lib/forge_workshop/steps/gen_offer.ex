defmodule ForgeWorkshop.Step.GenOffer do
  @moduledoc """
  Represents a single step in a DID workflow.
  """
  use TypedStruct

  typedstruct do
    field(:token, non_neg_integer())
    field(:title, String.t())
  end

  def new(token \\ 0, title \\ "") do
    %ForgeWorkshop.Step.GenOffer{token: token, title: title}
  end
end
