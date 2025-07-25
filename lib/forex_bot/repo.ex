defmodule ForexBot.Repo do
  use Ecto.Repo,
    otp_app: :forex_bot,
    adapter: Ecto.Adapters.Postgres
end
