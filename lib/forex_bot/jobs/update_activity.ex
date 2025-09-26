defmodule ForexBot.Jobs.UpdateActivity do
  use Oban.Worker, queue: :default, max_attempts: 5

  import ForexBot.Spider.ForexFactory
  import ForexBot.Utils
  import Nostrum.Struct.Embed
  import ForexBot.Slash.Today, only: [filter_important_events: 1]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"timestamp" => timestamp}}) do
    :logger.info("Updated activity at #{timestamp}")

    channel_id = Application.get_env(:forex_bot, :channel_id) |> String.to_integer()

    {:ok, message_id} = Cachex.get(:cache, "activity_message:#{channel_id}")
    message_id |> delete_old_activity(channel_id)

    events =
      parse_today_event(false)
      |> filter_important_events()

    update_events_list(events, channel_id)

    today_events = events |> Enum.group_by(& &1.time)

    found_events = Map.get(today_events, timestamp, [])

    found_events =
      found_events
      |> Enum.chunk_every(15)
      |> Enum.map(&create_embed/1)

    create_new_activity_message(channel_id, found_events)

    :ok
  end

  defp create_new_activity_message(channel_id, embeds) do
    {:ok, %Nostrum.Struct.Message{id: message_id}} =
      Nostrum.Api.Message.create(channel_id, embeds: embeds)

    Cachex.put(:cache, "activity_message:#{channel_id}", message_id)

    channel_id
  end

  defp delete_old_activity(nil, channel_id), do: channel_id

  defp delete_old_activity(message_id, channel_id) do
    Nostrum.Api.Message.delete(channel_id, message_id)

    channel_id
  end

  def create_embed(events) do
    today = localtime_now() |> DateTime.to_date() |> Date.to_string() |> String.replace("-", "/")

    %Nostrum.Struct.Embed{}
    |> put_title("Tin mới gần đây - #{today}")
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

  defp update_events_list(events, channel_id) do
    {:ok, message_id} = Cachex.get(:cache, "reset_daily_message:#{channel_id}")

    events = events |> Enum.chunk_every(15) |> Enum.map(&create_embed/1)
    Nostrum.Api.Message.edit(channel_id, message_id, embeds: events)
  end
end
