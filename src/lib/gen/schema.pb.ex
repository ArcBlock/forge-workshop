defmodule AbtDidWorkshop.Certificate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          from: String.t(),
          to: String.t(),
          iat: non_neg_integer,
          nbf: non_neg_integer,
          exp: non_neg_integer,
          content: String.t(),
          sig: String.t()
        }
  defstruct [:from, :to, :iat, :nbf, :exp, :content, :sig]

  field(:from, 1, type: :string)
  field(:to, 2, type: :string)
  field(:iat, 3, type: :uint64)
  field(:nbf, 4, type: :uint64)
  field(:exp, 5, type: :uint64)
  field(:content, 6, type: :string)
  field(:sig, 7, type: :bytes)
end
