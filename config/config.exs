# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :forex_calendar,
  ecto_repos: [ForexCalendar.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :forex_calendar, ForexCalendarWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ForexCalendarWeb.ErrorHTML, json: ForexCalendarWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ForexCalendar.PubSub,
  live_view: [signing_salt: "pEUTnw9U"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :forex_calendar, ForexCalendar.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  forex_calendar: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  forex_calendar: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message",
  metadata: [:request_id]

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
  ]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :forex_calendar, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: ForexCalendar.Repo,
  plugins: [
    {
      Oban.Plugins.Cron,
      timezone: "Asia/Ho_Chi_Minh",
      crontab: [
        {"*/1 * * * *", Bot.Jobs.ResetDaily}
        # {"13 18 * * *", Bot.Jobs.ResetDaily}
      ]
    }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
