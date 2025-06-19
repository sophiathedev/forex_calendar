defmodule Bot.Spider.ForexFactory do
  @base_url "https://www.forexfactory.com/calendar?day=today"

  def fetch_data do
    @base_url |> Crawly.fetch()
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

    if length(tds) < 8 do
      nil
    else
      %{
        time: extract_time(tds),
        currency: extract_currency(tds),
        impact: extract_impact(tds),
        event_name: extract_event_name(tds),
        actual: extract_actual(tds),
        forecast: extract_forecast(tds),
        previous: extract_previous(tds),
        event_id: extract_event_id(row)
      }
    end
  end

  defp extract_time(tds) do
    tds |> Floki.find("td.calendar__time") |> Floki.text() |> String.trim()
  end

  defp extract_currency(tds) do
    tds
    |> Enum.find(fn td ->
      case Floki.attribute(td, "class") do
        [class] -> String.contains?(class, "calendar__currency")
        _ -> false
      end
    end)
    |> case do
      nil ->
        nil

      td ->
        td
        |> Floki.find("span")
        |> Floki.text()
        |> String.trim()
    end
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
                  String.contains?(class, "ff-impact-red") -> "high"
                  String.contains?(class, "ff-impact-ora") -> "medium"
                  String.contains?(class, "ff-impact-yel") -> "low"
                  String.contains?(class, "ff-impact-gra") -> "holiday"
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
    |> Enum.find(fn td ->
      case Floki.attribute(td, "class") do
        [class] -> String.contains?(class, "calendar__actual")
        _ -> false
      end
    end)
    |> case do
      nil ->
        nil

      td ->
        td
        |> Floki.find("span")
        |> Floki.text()
        |> String.trim()
        |> case do
          "" -> nil
          value -> value
        end
    end
  end

  defp extract_forecast(tds) do
    tds
    |> Enum.find(fn td ->
      case Floki.attribute(td, "class") do
        [class] -> String.contains?(class, "calendar__forecast")
        _ -> false
      end
    end)
    |> case do
      nil ->
        nil

      td ->
        td
        |> Floki.find("span")
        |> Floki.text()
        |> String.trim()
        |> case do
          "" -> nil
          value -> value
        end
    end
  end

  defp extract_previous(tds) do
    tds
    |> Enum.find(fn td ->
      case Floki.attribute(td, "class") do
        [class] -> String.contains?(class, "calendar__previous")
        _ -> false
      end
    end)
    |> case do
      nil ->
        nil

      td ->
        td
        |> Floki.find("span")
        |> Floki.text()
        |> String.trim()
        |> case do
          "" -> nil
          value -> value
        end
    end
  end

  defp extract_event_id(row) do
    case Floki.attribute(row, "data-event-id") do
      [id] -> id
      _ -> nil
    end
  end
end
