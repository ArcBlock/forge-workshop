use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :forge_workshop, ForgeWorkshopWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
# config :forge_workshop, ForgeWorkshop.Repo,
#   username: "postgres",
#   password: "postgres",
#   database: "forge_workshop_test",
#   hostname: "localhost",
#   pool: Ecto.Adapters.SQL.Sandbox
