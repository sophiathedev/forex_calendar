defmodule Bot.Tasks.ResetDaily do
  import Bot.Spider.ForexFactory, only: [parse_today_event: 0]
  import ForexCalendar.Utils
  import Nostrum.Struct.Embed

  alias ForexCalendar.Servers
  alias Bot.Event

  @task_threshold_minute 3

  def perform do
    :logger.info("Performing daily reset task")

    announcement_channel_ids = Servers.get_all_announcement_channel_ids()

    today_events = parse_today_event() |> Enum.chunk_every(15) |> Enum.map(&create_embed/1)
    today_events = if Enum.empty?(today_events), do: [create_embed([])], else: today_events

    announcement_channel_ids
    |> Enum.map(&bulk_delete_old_messages/1)
    |> Enum.map(&send_daily_event_announcement(&1, today_events))

    # This does not effect performance because have cached
    # parse_today_event()
    # |> Enum.map(&Event.convert_time_24_hours/1)
    # |> Enum.group_by(& &1.time_24_hours)
    # |> Enum.each(&setting_scheduled_activity/1)
  end

  # defp setting_scheduled_activity({event_time, events}) do
  #   time_now = DateTime.now("Asia/Ho_Chi_Minh") |> elem(1)
  #   time_hm = {time_now.hour, time_now.minute}

  #   case compare_time_hm(event_time, time_hm) do
  #     -1 ->
  #       :ok

  #     _ ->
  #       {schedule_hour, schedule_minute} = get_next_threshold_minute(event_time)

  #       {event_hour, event_minute} = event_time
  #       total_minutes = event_minute + @task_threshold_minute
  #       schedule_date = if event_hour + div(total_minutes, 60) >= 24 do
  #         DateTime.to_date(time_now) |> Date.add(1)
  #       else
  #         DateTime.to_date(time_now)
  #       end

  #       date_str = Date.to_string(schedule_date) |> String.replace("-", "_")

  #       next_job = %Quantum.Job{
  #         schedule: "#{schedule_minute} #{schedule_hour} * * *",
  #         task: {Bot.Tasks.UpdateRecentActivity, :perform, [events]},
  #         name: :"next_activity_#{date_str}_#{schedule_hour}_#{schedule_minute}",
  #         overlap: false,
  #         run_strategy: Quantum.RunStrategy.All,
  #         timezone: "Asia/Ho_Chi_Minh"
  #       }

  #       ForexCalendar.Scheduler.add_job(next_job)
  #       :logger.info("Registered task #{next_job.name} at #{schedule_hour}:#{schedule_minute} on #{date_str}")
  #   end
  # end

  # defp get_next_threshold_minute({hour, minute}) do
  #   minute = minute + @task_threshold_minute
  #   new_hour = hour + div(minute, 60)
  #   {rem(new_hour, 24), rem(minute, 60)}
  # end

  # defp compare_time_hm({h1, m1}, {h2, m2}) do
  #   cond do
  #     h1 < h2 -> -1
  #     h1 > h2 -> 1
  #     m1 < m2 -> -1
  #     m1 > m2 -> 1
  #     true -> 0
  #   end
  # end

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
    {:ok, %Nostrum.Struct.Message{id: message_id}} = Nostrum.Api.Message.create(channel_id, embeds: [create_recent_activity_event_embed()])

    {:ok, true} = Cachex.put(:cache, "recent_activity:#{channel_id}", message_id)

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
