defmodule ForexBot.Slash.Today do
  import ForexBot.Spider.ForexFactory, only: [parse_today_event: 0]
  import ForexBot.Utils
  import Nostrum.Struct.Embed

  @behaviour Nosedrum.ApplicationCommand

  @impl true
  def description, do: "Lấy các tin đặc biệt trong ngày hiện tại"

  @impl true
  def type, do: :slash

  @impl true
  def command(_interaction) do
    today_events =
      parse_today_event()
      # |> filter_important_events()
      |> Enum.chunk_every(15)
      |> Enum.map(&create_embed/1)

    today_events = if Enum.empty?(today_events), do: [create_embed([])], else: today_events

    [embeds: today_events]
  end

  def filter_important_events(events) do
    important_currencies = ["USD", "EUR", "GBP", "JPY"]
    important_impact = ["High", "Non-Economic"]

    Enum.filter(events, fn event ->
      event.currency in important_currencies && event.impact in important_impact
    end)
  end

  def create_embed(events) do
    today = localtime_now() |> DateTime.to_date() |> Date.to_string() |> String.replace("-", "/")

    %Nostrum.Struct.Embed{}
    |> put_title("Forex News Today - #{today}")
    |> put_color(0x4285F4)
    |> put_events(events)
    |> put_footer("Powered by Elixir Nostrum.")
  end

  def put_events(embed, []) do
    embed |> put_description("Hiện tại không có tin nào đặc biệt.")
  end

  def put_events(embed, events) do
    events
    |> Enum.reduce(embed, fn event, accumulate_embed ->
      impact_emoji =
        case event.impact do
          "High" -> ":red_circle:"
          "Medium" -> ":orange_circle:"
          "Low" -> ":yellow_circle:"
          _ -> ":white_circle:"
        end

      currency_emoji =
        case event.currency do
          "USD" -> ":flag_us:"
          "EUR" -> ":flag_eu:"
          "GBP" -> ":flag_gb:"
          "JPY" -> ":flag_jp:"
          _ -> ""
        end

      field_event =
        [
          "#{impact_emoji} #{event.impact} Impact ([Details](#{event.event_url}))",
          "```Actual: #{event.actual}",
          "Forecast: #{event.forecast}",
          "Previous: #{event.previous}```"
        ]
        |> Enum.join("\n")

      accumulate_embed
      |> put_field(
        "`#{event.time}` #{currency_emoji} #{event.currency} - #{event.event_name}",
        field_event,
        true
      )
    end)
  end
end
