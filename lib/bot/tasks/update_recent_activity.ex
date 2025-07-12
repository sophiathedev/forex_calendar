defmodule Bot.Tasks.UpdateRecentActivity do
  import Nostrum.Struct.Embed
  import ForexCalendar.Utils

  alias ForexCalendar.Servers

  def perform(event) do
    :logger.info("Performing update recent activity task")

    announcement_channel_ids = Servers.get_all_announcement_channel_ids()

    announcement_channel_ids |> Enum.map(&(update_recent_activity(&1, event)))
  end

  defp update_recent_activity(channel_id, event) do
    case Cachex.get(:cache, "recent_activity:#{channel_id}") do
      {:ok, nil} ->
        :logger.error("No recent activity found for channel #{channel_id}")
        :ok

      {:ok, message_id} ->
        Nostrum.Api.Message.edit(channel_id, message_id, embeds: [create_recent_activity_event_embed(event)])
        :logger.info("Updated recent activity in channel: #{channel_id}")
    end
  end

  defp create_recent_activity_event_embed(event) do
    %Nostrum.Struct.Embed{}
    |> put_title("Recent events - #{localtime_string()}")
    |> put_color(0xEB4034)
    |> put_events(event)
    |> put_footer("Powered by Elixir Nostrum.")
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
