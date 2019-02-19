# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :abt_did_workshop,
  ecto_repos: [AbtDidWorkshop.Repo]

# Configures the endpoint
config :abt_did_workshop, AbtDidWorkshopWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "tP0sXPbNxA/aWZRlp/B2NiXthD/ryC5dYpyl9OPL40sRmXRxCg0VZhADZFoS18dX",
  render_errors: [view: AbtDidWorkshopWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: AbtDidWorkshop.PubSub, adapter: Phoenix.PubSub.PG2]

config :abt_did_workshop, :sample_keys, [
  "639A2938FD45B317AED1912F88D59BC1BA7D4DD47A1C4AD9A1C2B6BCF00B60F7A124B30D5D82BE5169BF91960B3C0DD992E63A4F9A5B23090473FD7C9836119C",
  "4DA94E2EA71550736C617DDAB1FE27DA4C75EE3ABF1F30BF1459C8D9EFB0CACF"
]

config :abt_did_workshop, :profile, [
  {"fullName", "Full Name"},
  {"ssn", "Social Security No."},
  {"birthday", "Birthday"}
]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
