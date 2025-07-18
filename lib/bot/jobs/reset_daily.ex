defmodule Bot.Jobs.ResetDaily do
  use Oban.Worker, queue: :default, max_attempts: 3

  import Bot.Spider.ForexFactory, only: [parse_today_event: 0]
  import ForexCalendar.Utils, only: [localtime_now: 0]
  import Nostrum.Struct.Embed

  alias ForexCalendar.Servers
  alias Bot.Event

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    :logger.info("Perform reset daily job")

    announcement_channel_ids = Servers.get_all_announcement_channel_ids()

    announcement_channel_ids
    |> Enum.map(&bulk_delete_messages/1)
    |> Enum.map(&send_daily_event_announcement/1)

    parse_today_event()
    |> Enum.map(&Event.convert_time_24_hours/1)
    |> Enum.group_by(& &1.time_24_hours)
    |> Enum.each(&schedule_activity/1)

    :logger.info("Performed reset daily")

    :ok
  end

  defp localtime_string do
    localtime_now()
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "/")
  end

  defp bulk_delete_messages(channel_id) do
    {:ok, messages} = Nostrum.Api.Channel.messages(channel_id, 100)

    message_ids = messages |> Enum.map(& &1.id)

    case Nostrum.Api.Channel.bulk_delete_messages(channel_id, message_ids) do
      {:error, reason} ->
        :logger.warning(
          "Bulk delete failed in channel #{channel_id}: #{inspect(reason)}. Falling back to individual deletion."
        )

        # Fallback: delete messages one by one
        delete_messages_individually(channel_id, message_ids)

      _ ->
        :logger.info("Successfully bulk deleted #{length(message_ids)} messages in channel #{channel_id}")
        channel_id
    end
  end

  defp delete_messages_individually(channel_id, message_ids) do
    deleted_count =
      message_ids
      |> Enum.reduce(0, fn message_id, acc ->
        case Nostrum.Api.Message.delete(channel_id, message_id) do
          :ok ->
            acc + 1

          {:error, reason} ->
            :logger.warning(
              "Failed to delete message #{message_id} in channel #{channel_id}: #{inspect(reason)}"
            )
            acc
        end
      end)

    :logger.info("Successfully deleted #{deleted_count}/#{length(message_ids)} messages individually in channel #{channel_id}")
    channel_id
  end

  defp send_daily_event_announcement(channel_id) do
    {:ok, %Nostrum.Struct.Message{id: message_id}} =
      Nostrum.Api.Message.create(channel_id, embeds: [create_recent_activity_event_embed()])

    {:ok, true} = Cachex.put(:cache, "recent_activity:#{channel_id}", message_id)

    channel_id
  end

  defp create_recent_activity_event_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("Recent events - #{localtime_string()}")
    |> put_description("There are not any recent events.")
    |> put_color(0xEB4034)
    |> put_footer("Powered by Elixir Nostrum.")
  end

  # :noop -> NO OPeration
  def schedule_activity({nil, _}), do: :noop

  def schedule_activity({timestamp, events}) do
    # remove time 24 hours for jason encoder
    events = Enum.map(events, fn e -> %Bot.Event{e | time_24_hours: nil} end)

    {hour, minute} = timestamp

    {:ok, current_datetime_now} = DateTime.now("Asia/Ho_Chi_Minh")

    {:ok, target_time_in_day} = Time.new(hour, minute, 0)

    {:ok, schedule_activity_time} =
      DateTime.to_date(current_datetime_now)
      |> DateTime.new(target_time_in_day, "Asia/Ho_Chi_Minh")

    case DateTime.compare(schedule_activity_time, current_datetime_now) do
      :gt ->
        %{"events" => events}
        |> Bot.Jobs.UpdateActivity.new(scheduled_at: schedule_activity_time)
        |> Oban.insert()
        |> case do
          {:ok, job} ->
            :logger.info("Scheduled job for activity at #{hour}:#{minute} with job ID: #{job.id}")
            job

          {:error, reason} ->
            :logger.error("Failed to schedule job for activity at #{hour}:#{minute}: #{inspect(reason)}")
            :noop
        end

      _ ->
        :logger.warning("Skipped scheduling for past time: #{hour}:#{minute}")
        :noop
    end
  end
end
