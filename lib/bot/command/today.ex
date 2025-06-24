defmodule Bot.Command.Today do
  import Bot.Spider.ForexFactory, only: [parse_today_event: 0]
  import ForexCalendar.Utils
  import Nostrum.Struct.Embed

  @behaviour Nosedrum.ApplicationCommand

  @impl true
  def description, do: "Get today's Forex events"

  @impl true
  def type, do: :slash

  @impl true
  def command(_interaction) do
    today_events = parse_today_event() |> Enum.chunk_every(20) |> Enum.map(&create_embed/1)

    [embeds: today_events]
  end

  defp create_embed(events) do
    today = localtime_now() |> DateTime.to_date() |> Date.to_string() |> String.replace("-", "/")

    %Nostrum.Struct.Embed{}
    |> put_title("Forex News Today - #{today}")
    |> put_color(0x4285F4)
    |> put_events(events)
    |> put_footer("Powered by Elixir Nostrum.")
  end

  defp put_events(embed, []) do
    embed |> put_description("No news found for the specified criteria.")
  end

  defp put_events(embed, events) do
    events
    |> Enum.reduce(embed, fn event, accumulate_embed ->
      impact_emoji =
        case event.impact do
          "High" -> ":red_circle:"
          "Medium" -> ":orange_circle:"
          "Low" -> ":yellow_circle:"
          _ -> ":white_circle:"
        end

      field_event =
        [
          "#{impact_emoji} #{event.impact} Impact ([Details](#{event.event_url}))",
          "```Forecast: #{event.forecast}",
          "Previous: #{event.previous}```"
        ]
        |> Enum.join("\n")

      accumulate_embed
      |> put_field(
        "`#{event.time}`  #{event.currency} - #{event.event_name}",
        field_event,
        true
      )
    end)
  end
end
