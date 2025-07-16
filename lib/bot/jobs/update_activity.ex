defmodule Bot.Jobs.UpdateActivity do
  use Oban.Worker, queue: :default, max_attempts: 3

  import ForexCalendar.Utils, only: [localtime_now: 0]
  import Nostrum.Struct.Embed

  alias ForexCalendar.Servers

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"events" => events}}) do
    :logger.info("Perform update activity job")

    announcement_channel_ids = Servers.get_all_announcement_channel_ids()

    embed_events =
      events
      |> Enum.map(fn event_map ->
        atom_map = for {key, val} <- event_map, into: %{} do
          atom_key = if is_binary(key), do: String.to_atom(key), else: key
          {atom_key, val}
        end
        struct(Bot.Event, atom_map)
      end)
      |> create_recent_activity_event_embed()

    announcement_channel_ids
    |> Enum.map(fn channel_id ->
      {:ok, message_id} = Cachex.get(:cache, "recent_activity:#{channel_id}")

      case message_id do
        nil -> nil
        _ -> {channel_id, message_id}
      end
    end)
    |> Enum.filter(fn
      nil -> false
      _ -> true
    end)
    |> Enum.each(fn message_payload ->
      edit_activity_message(message_payload, embed_events)
    end)

    :ok
  end

  defp create_recent_activity_event_embed(events) do
    %Nostrum.Struct.Embed{}
    |> put_title("Recent events - #{localtime_string()}")
    |> put_color(0xEB4034)
    |> put_events(events)
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
          "```Actual: #{event.actual}",
          "Forecast: #{event.forecast}",
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

  defp edit_activity_message({channel_id, message_id}, embed_events) do
    Nostrum.Api.Message.delete(channel_id, message_id)
    {:ok, message} = Nostrum.Api.Message.create(channel_id, embeds: [embed_events])

    %Nostrum.Struct.Message{id: new_message_id} = message
    {:ok, true} = Cachex.put(:cache, "recent_activity:#{channel_id}", new_message_id)

    :noop
  end
end
