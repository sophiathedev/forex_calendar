defmodule ForexBot.Jobs.Cpi do
  use Oban.Worker, queue: :default, max_attempts: 3

  import ForexBot.Utils, only: [localtime_now: 0]

  @month_params [
    "jan",
    "feb",
    "mar",
    "apr",
    "may",
    "jun",
    "jul",
    "aug",
    "sep",
    "oct",
    "nov",
    "dec"
  ]

  @impl Oban.Worker
  def perform(_args) do
    :logger.info("Perform crawling CPI")

    if Cachex.exists?(:cache, "cpi_data") == {:ok, true} do
      :logger.info("Clear old CPI data in cache")
      Cachex.del(:cache, "cpi_data")
    end

    current_month = localtime_now().month
    current_year = localtime_now().year

    crawled_result =
      (current_month - 6)..current_month
      |> Enum.to_list()
      |> Enum.map(fn m ->
        {
          if(m > 0, do: m, else: 12 + m),
          if(m > 0, do: current_year, else: current_year - 1)
        }
      end)
      |> Enum.map(fn {month, year} ->
        month_param = Enum.at(@month_params, month - 1)

        "https://www.forexfactory.com/calendar?month=#{month_param}.#{year}"
        |> ForexBot.Spider.ForexFactory.parse_cpi()
        |> Enum.map(fn event ->
          event_day = String.slice(event.date, 4..5) |> String.to_integer()
          {:ok, event_date} = Date.new(year, month, event_day)

          %{event | date: event_date}
        end)
      end)
      |> List.flatten()
      |> filter_important_events()

    Cachex.put(:cache, "cpi_data", crawled_result)

    :ok
  end

  defp filter_important_events(events) do
    important_currencies = ["USD", "EUR", "GBP", "JPY"]
    important_impact = ["High", "Non-Economic"]

    important_event_names = [
      "Core CPI m/m",
      "CPI m/m",
      "CPI y/y",
      "Core PPI m/m",
      "PPI m/m",
      "Unemployment Claims",
      "Core Retail Sales m/m",
      "Prelim UoM Consumer Sentiment",
      "Prelim UoM Inflation Expectations",
      "ECB Press Conference",
      "ADP Non-Farm Employment Change",
      "ISM Manufacturing PMI",
      "Average Hourly Earnings m/m",
      "Non-Farm Employment Change",
      "Unemployment Rate",
      "ISM Services PMI",
      "Retail Sales m/m",
      "Federal Funds Rate",
      "FOMC Economic Projections",
      "FOMC Statement",
      "FOMC Press Conference"
    ]

    Enum.filter(events, fn event ->
      event.currency in important_currencies && event.impact in important_impact
    end)
    |> Enum.filter(fn event ->
      event.event_name in important_event_names
    end)
  end
end
