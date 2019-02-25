defmodule AbtDidWorkshop.Certificate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          issuer: String.t(),
          iat: non_neg_integer,
          exp: non_neg_integer,
          content: String.t(),
          sig: String.t()
        }
  defstruct [:issuer, :iat, :exp, :content, :sig]

  field(:issuer, 1, type: :string)
  field(:iat, 2, type: :uint64)
  field(:exp, 3, type: :uint64)
  field(:content, 4, type: :string)
  field(:sig, 5, type: :bytes)
end
