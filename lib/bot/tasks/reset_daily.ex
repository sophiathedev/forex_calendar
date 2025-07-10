defmodule Bot.Tasks.ResetDaily do
  import Bot.Spider.ForexFactory, only: [parse_today_event: 0]
  import ForexCalendar.Utils
  import Nostrum.Struct.Embed

  alias ForexCalendar.Servers

  def perform do
    :logger.info("Performing daily reset task")

    announcement_channel_ids = Servers.get_all_announcement_channel_ids()

    today_events = parse_today_event() |> Enum.chunk_every(15) |> Enum.map(&create_embed/1)
    today_events = if Enum.empty?(today_events), do: [create_embed([])], else: today_events

    announcement_channel_ids
    |> Enum.map(&bulk_delete_old_messages/1)
    |> Enum.map(&send_daily_event_announcement(&1, today_events))
  end

  defp bulk_delete_old_messages(channel_id) do
    {:ok, messages} = Nostrum.Api.Channel.messages(channel_id, 1000)

    messages = messages |> Enum.map(& &1.id)

    case Nostrum.Api.Channel.bulk_delete_messages(channel_id, messages) do
      {:error, reason} ->
        :logger.error("Failed to bulk delete old messages in channel #{channel_id}: #{inspect(reason)}")

      _ ->
        :ok
    end

    channel_id
  end

  defp send_daily_event_announcement(channel_id, today_events) do
    Nostrum.Api.Message.create(channel_id, embeds: today_events)
    Nostrum.Api.Message.create(channel_id, embeds: [create_recent_activity_event_embed()])

    :logger.info("Sent daily event announcement to channel: #{channel_id}")
    channel_id
  end

  defp create_recent_activity_event_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("Recent events - #{localtime_string()}")
    |> put_description("There are not any recent events.")
    |> put_color(0xEB4034)
    |> put_footer("Powered by Elixir Nostrum.")
  end

  defp create_embed(events) do
    %Nostrum.Struct.Embed{}
    |> put_title("Forex News Today - #{localtime_string()}")
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

  defp localtime_string do
    localtime_now()
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "/")
  end
end
