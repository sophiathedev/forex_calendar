defmodule ForexCalendar.Repo do
  use Ecto.Repo,
    otp_app: :forex_calendar,
    adapter: Ecto.Adapters.Postgres
end
