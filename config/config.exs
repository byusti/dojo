# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :dojo,
  ecto_repos: [Dojo.Repo]

# Configures the endpoint
config :dojo, DojoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6OFS0/PTjxt7qG4rj5zC2WmrpEZOTQSA0n0w3jILDKXiJB4LoqiMGzsuSytDBmvV",
  render_errors: [view: DojoWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Dojo.PubSub,
  live_view: [signing_salt: "zlw3ir6l"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

config :esbuild,
  version: "0.13.4",
  default: [
    args:
      ~w(js/Room.bs.js js/Home.bs.js js/friend_invite.js js/friend_pending.js js/login.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
