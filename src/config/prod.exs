use Mix.Config

config :logger, level: :info

config :forge_workshop, ForgeWorkshopWeb.Endpoint,
  server: true,
  url: [host: "did-workshop.arcblock.co", port: 8807],
  http: [port: 8807],
  debug_errors: true,
  check_origin: false,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :phoenix, :stacktrace_depth, 20
