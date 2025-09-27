defmodule ForexBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Application.put_env(:elixir, :ansi_enabled, true)

    bot_opts = %{
      name: "ForexBot",
      consumer: ForexBot.Consumer,
      intents: :all,
      wrapped_token: fn -> Application.get_env(:forex_bot, :discord_token) end
    }

    children = [
      ForexBotWeb.Telemetry,
      ForexBot.Repo,
      {DNSCluster, query: Application.get_env(:forex_bot, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:forex_bot, Oban)},
      {Phoenix.PubSub, name: ForexBot.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ForexBot.Finch},
      # Start a worker by calling: ForexBot.Worker.start_link(arg)
      # {ForexBot.Worker, arg},
      # Start to serve requests, typically the last entry
      ForexBotWeb.Endpoint,
      {Cachex, :cache},
      {Nosedrum.Storage.Dispatcher, name: Nosedrum.Storage.Dispatcher},
      {Nostrum.Bot, bot_opts}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ForexBot.Supervisor]
    result = Supervisor.start_link(children, opts)

    # ForexBot.Jobs.ResetDaily.new(%{}) |> Oban.insert()
    ForexBot.Jobs.Cpi.new(%{}) |> Oban.insert()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ForexBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
