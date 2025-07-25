# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :forex_bot,
  ecto_repos: [ForexBot.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :forex_bot, ForexBotWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ForexBotWeb.ErrorHTML, json: ForexBotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ForexBot.PubSub,
  live_view: [signing_salt: "Y/2LN7dF"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :forex_bot, ForexBot.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  forex_bot: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  forex_bot: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message",
  metadata: [:request_id],
  level: :debug

config :logger, :nostrum,
  level: :info,
  backends: [:console],
  format: "$time $metadata[$level] $message",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :crawly,
  concurrent_requests_per_domain: 1,
  closespider_timeout: 10,
  request_timeout: 30_000,
  middlewares: [
    Crawly.Middlewares.DomainFilter,
    Crawly.Middlewares.UniqueRequest,
    {Crawly.Middlewares.UserAgent,
     user_agents: [
       "Crawly Bot"
     ]},
    {Crawly.Middlewares.RequestOptions,
     [
       timeout: 30_000,
       recv_timeout: 30_000,
       follow_redirect: true,
       max_redirect: 5,
       hackney: [
         connect_timeout: 10_000,
         recv_timeout: 30_000,
         follow_redirect: true,
         max_redirect: 5,
         pool: :default
       ]
     ]}
  ],
  pipelines: [
    {Crawly.Pipelines.WriteToFile, folder: "/tmp", extension: "jl"}
  ],
  spiders: [
    Bot.Spider.ForexFactory
  ],
  start_http_api?: false,
  manager_operations_timeout: 30_000

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :forex_bot, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: ForexBot.Repo,
  plugins: [
    # {
    #   Oban.Plugins.Cron,
    #   timezone: "Asia/Ho_Chi_Minh",
    #   crontab: [
    #     # {"*/1 * * * *", Bot.Jobs.ResetDaily}
    #     {"1 0 * * *", Bot.Jobs.ResetDaily}
    #   ]
    # }
    {
      Oban.Plugins.Cron,
      timezone: "Asia/Ho_Chi_Minh",
      crontab: [
        {"1 0 * * *", ForexBot.Jobs.ResetDaily}
      ]
    }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
