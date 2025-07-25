defmodule ForexBot.Jobs.ResetDaily do
  use Oban.Worker, queue: :default, max_attempts: 1

  import ForexBot.Slash.Today
  import ForexBot.Spider.ForexFactory

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    :logger.info("Perform reset daily job")

    announce_channel_id = Application.get_env(:forex_bot, :channel_id) |> String.to_integer()

    announce_channel_id |> bulk_delete_messages()

    today_events =
      parse_today_event()
      # |> filter_important_events()
      |> Enum.chunk_every(15)
      |> Enum.map(&create_embed/1)
    today_events = if Enum.empty?(today_events), do: [create_embed([])], else: today_events
    Nostrum.Api.Message.create(announce_channel_id, embeds: today_events)

    parse_today_event()
    |> Enum.map(& &1.time)
    |> Enum.uniq()
    |> Enum.map(fn timestamp ->
      {timestamp, ForexBot.Types.Event.convert_time_24_hours(timestamp)}
    end)
    |> Map.new()
    |> Enum.each(&schedule_activity/1)

    :ok
  end

  @schedule_threshold_minutes 3
  defp schedule_activity({timestamp, time_24_hours}) do
    {hour, minute} = time_24_hours
    {:ok, current_datetime_now} = DateTime.now("Asia/Ho_Chi_Minh")
    {:ok, target_time_in_day} = Time.new(hour, minute, 0)
    target_time_in_day = Time.add(target_time_in_day, @schedule_threshold_minutes, :minute)

    {:ok, schedule_datetime} =
      DateTime.to_date(current_datetime_now)
      |> DateTime.new(target_time_in_day, "Asia/Ho_Chi_Minh")

    case DateTime.compare(schedule_datetime, current_datetime_now) do
      :gt ->
        %{"timestamp" => timestamp}
        |> ForexBot.Jobs.UpdateActivity.new()
        |> Oban.insert()
        |> case do
          {:ok, _job} ->
            :logger.info("Scheduled job for timestamp #{timestamp} at #{schedule_datetime}")
          {:error, reason} ->
            :logger.error("Failed to schedule job for timestamp #{timestamp}: #{inspect(reason)}")
        end

      _ ->
        :logger.info("Skipping scheduling for #{schedule_datetime} as it is in the past or now")
    end
  end

  defp bulk_delete_messages(channel_id) do
    {:ok, messages} = Nostrum.Api.Channel.messages(channel_id, 100)
    message_ids = Enum.map(messages, & &1.id)

    channel_id |> delete_messages(message_ids)
  end

  defp delete_messages(channel_id, []), do: channel_id
  defp delete_messages(channel_id, message_id) when length(message_id) == 1 do
    Nostrum.Api.Message.delete(channel_id, hd(message_id))

    channel_id
  end
  defp delete_messages(channel_id, message_ids) do
    Nostrum.Api.Channel.bulk_delete_messages(channel_id, message_ids)

    channel_id
  end
end
