defmodule ForexCalendar.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Application.put_env(:elixir, :ansi_enabled, true)

    bot_opts = %{
      name: "ForexCalendar",
      consumer: Bot.Consumer,
      intents: :all,
      wrapped_token: fn -> Application.get_env(:forex_calendar, :discord_token) end
    }

    children = [
      ForexCalendarWeb.Telemetry,
      ForexCalendar.Repo,
      {DNSCluster, query: Application.get_env(:forex_calendar, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:forex_calendar, Oban)},
      {Phoenix.PubSub, name: ForexCalendar.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ForexCalendar.Finch},
      # Start a worker by calling: ForexCalendar.Worker.start_link(arg)
      # {ForexCalendar.Worker, arg},
      # Start the Quantum scheduler
      # Start to serve requests, typically the last entry
      ForexCalendarWeb.Endpoint,
      {Cachex, :cache},
      {Nosedrum.Storage.Dispatcher, name: Nosedrum.Storage.Dispatcher},
      {Nostrum.Bot, bot_opts}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ForexCalendar.Supervisor]
    result = Supervisor.start_link(children, opts)

    %{}
    |> Bot.Jobs.ResetDaily.new()
    |> Oban.insert()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ForexCalendarWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
