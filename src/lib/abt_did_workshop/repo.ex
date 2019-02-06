defmodule AbtDidWorkshop.Repo do
  use Ecto.Repo,
    otp_app: :abt_did_workshop,
    adapter: Ecto.Adapters.Postgres
end
