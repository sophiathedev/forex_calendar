defmodule ForexBot.Types.Event do
  @derive {Jason.Encoder,
           only: [
             :time,
             :date,
             :currency,
             :actual,
             :event_name,
             :impact,
             :forecast,
             :previous,
             :event_id,
             :event_url,
             :time_24_hours
           ]}

  defstruct [
    :time,
    :date,
    :currency,
    :actual,
    :event_name,
    :impact,
    :forecast,
    :previous,
    :event_id,
    :event_url,
    :time_24_hours
  ]

  def convert_time_24_hours(time) do
    case parse_time_string(time) do
      {:ok, hour, minute} ->
        {hour, minute}

      :error ->
        {-1, -1}
    end
  end

  defp parse_time_string(time_string) when is_binary(time_string) do
    regex = ~r/^(\d{1,2}):(\d{2})(am|pm)$/i

    case Regex.run(regex, String.downcase(time_string)) do
      [_full_match, hours_str, minutes_str, period] ->
        hours = String.to_integer(hours_str)
        minutes = String.to_integer(minutes_str)

        converted_hours = convert_to_24h(hours, period)

        {:ok, converted_hours, minutes}

      nil ->
        :error
    end
  end

  defp parse_time_string(_), do: :error

  defp convert_to_24h(hours, "am") when hours == 12, do: 0
  defp convert_to_24h(hours, "am"), do: hours
  defp convert_to_24h(hours, "pm") when hours == 12, do: 12
  defp convert_to_24h(hours, "pm"), do: hours + 12
end
