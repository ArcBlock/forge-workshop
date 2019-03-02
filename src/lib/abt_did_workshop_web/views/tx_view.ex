defmodule AbtDidWorkshopWeb.TxView do
  use AbtDidWorkshopWeb, :view

  def behavior_value(_, nil), do: ""

  def behavior_value(tag_id, tx), do: do_behavior_value(tag_id, tx.tx_behaviors)

  def extract_id(nil), do: ""

  def extract_id(tx) do
    case tx.id do
      nil -> ""
      tx_id -> inspect(tx_id)
    end
  end

  defp do_behavior_value(_, behaviors) when not is_list(behaviors), do: ""

  defp do_behavior_value(tag_id, behaviors) do
    [tx_type, beh, col] = String.split(tag_id, "_")

    behaviors
    |> Enum.filter(fn b -> b.tx_type == tx_type and b.behavior == beh end)
    |> List.first()
    |> Kernel.||(%{})
    |> Map.get(String.to_atom(col), "")
  end

  # def do_extract_id(behaviors) when not is_list(behaviors), do: []

  # def do_extract_id(behaviors) do
  #   behaviors
  #   |> Enum.map(fn b -> b.id end)
  #   |> Enum.reject(&is_nil/1)
  # end
end
