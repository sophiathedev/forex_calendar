defmodule ForexCalendar.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Dotenv.load!

    bot_opts = %{
      name: "ForexCalendar",
      consumer: Bot.Consumer,
      intents: :all,
      wrapped_token: fn -> System.fetch_env!("DISCORD_TOKEN") end
    }

    children = [
      ForexCalendarWeb.Telemetry,
      ForexCalendar.Repo,
      {DNSCluster, query: Application.get_env(:forex_calendar, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ForexCalendar.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ForexCalendar.Finch},
      # Start a worker by calling: ForexCalendar.Worker.start_link(arg)
      # {ForexCalendar.Worker, arg},
      # Start to serve requests, typically the last entry
      ForexCalendarWeb.Endpoint,
      {Nosedrum.Storage.Dispatcher, name: Nosedrum.Storage.Dispatcher},
      {Nostrum.Bot, bot_opts},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ForexCalendar.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ForexCalendarWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
