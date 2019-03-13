defmodule AbtDidWorkshop.Tables.AppTable do
  @moduledoc false

  import Ecto.Query
  alias AbtDidWorkshop.{AppAuthState, Repo}

  def get() do
    from(a in AppAuthState)
    |> Repo.one()
  end

  def delete() do
    from(a in AppAuthState)
    |> Repo.delete_all()
  end
end
