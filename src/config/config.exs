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

config :abt_did_workshop,
  sample_keys: [
    "639A2938FD45B317AED1912F88D59BC1BA7D4DD47A1C4AD9A1C2B6BCF00B60F7A124B30D5D82BE5169BF91960B3C0DD992E63A4F9A5B23090473FD7C9836119C",
    "4DA94E2EA71550736C617DDAB1FE27DA4C75EE3ABF1F30BF1459C8D9EFB0CACF"
  ],
  profile: [
    {"fullName", "Full Name"},
    {"email", "Email"},
    {"phone", "Phone"},
    {"birthday", "Birthday"}
  ],
  agreement: [
    %{
      meta: %{
        description: "Data policy",
        id: "1"
      },
      uri: "/workshop/api/agreement/1",
      hash: %{
        method: "sha256",
        digest: "z73jC7FoJMSpmLwsrWF7oT5xBGYaMRNrWs7ajBEB2vuJh"
      },
      type: "agreement",
      content:
        "Information and content you provide. We collect the content, communications and other information you provide when you use our Products, including when you sign up for an account, create or share content, and message or communicate with others. This can include information in or about the content you provide (like metadata), such as the location of a photo or the date a file was created. It can also include what you see through features we provide, such as our camera, so we can do things like suggest masks and filters that you might like, or give you tips on using camera formats. Our systems automatically process content and communications you and others provide to analyze context and what's in them for the purposes described below. Learn more about how you can control who can see the things you share."
    },
    %{
      meta: %{
        description: "Terms of Service",
        id: "2"
      },
      uri: "/workshop/api/agreement/2",
      hash: %{
        method: "sha3",
        digest: "z62acdB8rK5kpUarnPiDfBnEHxcjpuwhNt1BdAUYDaeN5"
      },
      type: "agreement",
      content:
        "Don’t misuse our Services. For example, don’t interfere with our Services or try to access them using a method other than the interface and the instructions that we provide. You may use our Services only as permitted by law, including applicable export and re-export control laws and regulations. We may suspend or stop providing our Services to you if you do not comply with our terms or policies or if we are investigating suspected misconduct."
    }
  ],
  app_info: %{
    name: "ABT DID Workshop",
    subtitle: "Play with DID authentication protocol.",
    description:
      "A simple workshop for developers to quickly develop, design and debug the DID flow.",
    icon: "/images/logo@2x.png",
    copyright: "https://example-application/copyright",
    publisher: "did:abt:zNKSHDK5KTZ5bdxfHoKp6F2iibbpLriYJDSi"
  },
  deep_link_path: "https://abtwallet.io/i/",
  wallet: %{moniker_prefix: "stu", passphrase: "abcd1234"},
  robert: %{
    address: "z1YgP3zaVdQzB9gC3kHAyTiiMMPZhLzCLDP",
    pk:
      <<41, 245, 57, 253, 111, 41, 92, 141, 236, 179, 248, 104, 214, 70, 231, 252, 248, 254, 240,
        67, 143, 71, 217, 171, 206, 213, 160, 125, 70, 142, 146, 229>>,
    sk:
      <<130, 120, 1, 15, 32, 115, 128, 114, 252, 49, 69, 204, 87, 211, 69, 172, 138, 163, 53, 180,
        98, 48, 217, 92, 123, 220, 46, 142, 126, 75, 93, 19, 41, 245, 57, 253, 111, 41, 92, 141,
        236, 179, 248, 104, 214, 70, 231, 252, 248, 254, 240, 67, 143, 71, 217, 171, 206, 213,
        160, 125, 70, 142, 146, 229>>,
    type: [address: 1, hash: 1, pk: 0, role: 0]
  }

# Configures Drab
config :drab, AbtDidWorkshopWeb.Endpoint, otp_app: :abt_did_workshop
# Configures Drab for webpack
config :drab, AbtDidWorkshopWeb.Endpoint, js_socket_constructor: "window.__socket"

# Configures default Drab file extension
config :phoenix, :template_engines, drab: Drab.Live.Engine

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :abt_did_workshop, :env, "#{Mix.env()}"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
