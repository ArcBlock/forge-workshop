defmodule ForgeWorkshop.WorkshopAsset do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          from: String.t(),
          to: String.t(),
          iat: non_neg_integer,
          nbf: non_neg_integer,
          exp: non_neg_integer,
          title: String.t(),
          content: integer,
          sig: String.t()
        }
  defstruct [:from, :to, :iat, :nbf, :exp, :title, :content, :sig]

  field(:from, 1, type: :string)
  field(:to, 2, type: :string)
  field(:iat, 3, type: :uint64)
  field(:nbf, 4, type: :uint64)
  field(:exp, 5, type: :uint64)
  field(:title, 6, type: :string)
  field(:content, 7, type: :int64)
  field(:sig, 8, type: :bytes)
end
