defmodule AbtDidWorkshop.Tables.AppTable do
  @moduledoc false

  import Ecto.Query
  alias AbtDidWorkshop.{AppAuthState, Repo}

  def get() do
    from(a in AppAuthState)
    |> Repo.all()
    |> List.first()
  end

  def delete() do
    from(a in AppAuthState)
    |> Repo.delete_all()
  end

  def insert(state) do
    %AppAuthState{}
    |> AppAuthState.changeset(state)
    |> Repo.insert()
  end
end
