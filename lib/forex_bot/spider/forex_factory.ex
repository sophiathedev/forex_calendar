defmodule ForexBot.Spider.ForexFactory do
  import ForexBot.Utils, only: [today_id: 0]
  @today_url "https://www.forexfactory.com/calendar?day=today"

  def fetch_today(url \\ @today_url) do
    url |> Crawly.fetch()
  end

  def parse_cpi(url) do
    %HTTPoison.Response{body: crawled_body} = fetch_today(url)

    parse_item(crawled_body)
    |> fill_missing_times()
    |> Enum.map(fn crawled_event ->
      struct(ForexBot.Types.Event, crawled_event)
    end)
    |> Enum.map_reduce(nil, fn event, extracted_date ->
      extracted_date =
        if event.date != nil and event.date != "" do
          event.date |> String.slice(4..9)
        else
          extracted_date
        end

      {%ForexBot.Types.Event{event | date: extracted_date}, extracted_date}
    end)
    |> elem(0)
  end

  def parse_today_event(cache \\ true) do
    {:ok, exists_today_event_body} = Cachex.exists?(:cache, "event#{today_id()}")

    {:ok, body} =
      if exists_today_event_body && cache == true do
        Cachex.get(:cache, "event#{today_id()}")
      else
        %HTTPoison.Response{body: crawled_body} = fetch_today()

        {:ok, crawled_body}
      end

    if not exists_today_event_body do
      {:ok, true} = Cachex.put(:cache, "event#{today_id()}", body, expire: 10 * 60 * 1000)
    end

    parse_item(body)
    |> fill_missing_times()
    |> Enum.map(fn crawled_event ->
      struct(ForexBot.Types.Event, crawled_event)
    end)
  end

  defp fill_missing_times(events) do
    {filled_events, _} =
      Enum.map_reduce(events, nil, fn event, last_time ->
        current_time = if event.time == nil or event.time == "", do: last_time, else: event.time
        updated_event = %{event | time: current_time}
        {updated_event, current_time}
      end)

    filled_events
  end

  def parse_item(body) do
    {:ok, document} = Floki.parse_document(body)

    rows = document |> Floki.find("tr.calendar__row")

    parsed_events =
      rows
      |> Enum.map(&parse_row/1)
      |> Enum.filter(fn event -> event != nil end)
      |> Enum.filter(fn event ->
        event.event_name != nil and event.event_name != ""
      end)

    parsed_events
  end

  defp parse_row(row) do
    tds = row |> Floki.find("td")

    if length(tds) >= 8 do
      event_response = %{
        time: extract_time(tds),
        date: extract_date(tds),
        currency: extract_currency(tds),
        impact: extract_impact(tds),
        event_name: extract_event_name(tds),
        actual: extract_actual(tds),
        forecast: extract_forecast(tds),
        previous: extract_previous(tds),
        event_id: extract_event_id(row)
      }

      event_url =
        if event_response.event_id do
          @today_url <> "#detail=#{event_response.event_id}"
        else
          @today_url
        end

      event_response |> Map.put(:event_url, event_url)
    end
  end

  defp extract_time(tds) do
    tds |> Floki.find("td.calendar__time") |> Floki.text() |> String.trim()
  end

  defp extract_date(tds) do
    tds |> Floki.find("td.calendar__date") |> Floki.text() |> String.trim()
  end

  defp extract_currency(tds) do
    tds |> Floki.find("td.calendar__currency") |> Floki.text() |> String.trim()
  end

  defp extract_impact(tds) do
    impact_td =
      tds
      |> Enum.find(fn td ->
        case Floki.attribute(td, "class") do
          [class] -> String.contains?(class, "calendar__impact")
          _ -> false
        end
      end)

    case impact_td do
      nil ->
        nil

      td ->
        icon = td |> Floki.find("span.icon") |> List.first()

        case icon do
          nil ->
            "unknown"

          icon_elem ->
            case Floki.attribute(icon_elem, "class") do
              [class] ->
                cond do
                  String.contains?(class, "ff-impact-red") -> "High"
                  String.contains?(class, "ff-impact-ora") -> "Medium"
                  String.contains?(class, "ff-impact-yel") -> "Low"
                  String.contains?(class, "ff-impact-gra") -> "Non-Economic"
                  true -> "unknown"
                end

              _ ->
                "unknown"
            end
        end
    end
  end

  defp extract_event_name(tds) do
    tds
    |> Enum.find(fn td ->
      case Floki.attribute(td, "class") do
        [class] -> String.contains?(class, "calendar__event")
        _ -> false
      end
    end)
    |> case do
      nil ->
        nil

      td ->
        td
        |> Floki.find(".calendar__event-title")
        |> Floki.text()
        |> String.trim()
    end
  end

  defp extract_actual(tds) do
    tds
    |> Floki.find("td.calendar__actual")
    |> Floki.text()
    |> String.trim()
  end

  defp extract_forecast(tds) do
    tds
    |> Floki.find("td.calendar__forecast")
    |> Floki.text()
    |> String.trim()
  end

  defp extract_previous(tds) do
    tds
    |> Floki.find("td.calendar__previous")
    |> Floki.text()
    |> String.trim()
  end

  defp extract_event_id(row) do
    case Floki.attribute(row, "data-event-id") do
      [id] -> id
      _ -> nil
    end
  end
end
