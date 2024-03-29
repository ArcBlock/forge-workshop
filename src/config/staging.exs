use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :forge_workshop, ForgeWorkshopWeb.Endpoint,
  server: true,
  url: [host: "localhost", port: 8807],
  http: [port: 8807],
  debug_errors: true,
  check_origin: false

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  format: "[$level] $message\n",
  level: :info

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
# config :forge_workshop, ForgeWorkshop.Repo,
#   username: "postgres",
#   password: "postgres",
#   database: "forge_workshop_staging",
#   hostname: "localhost",
#   pool_size: 10
