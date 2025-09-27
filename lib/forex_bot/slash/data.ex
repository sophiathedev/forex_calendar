defmodule ForexBot.Slash.Data do
  import ForexBot.Utils, only: [localtime_now: 0]
  import Nostrum.Struct.Embed
  import Nostrum.Struct.Component.Button, only: [interaction_button: 3]
  import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]

  alias Nostrum.Struct.ApplicationCommandInteractionDataOption

  @behaviour Nosedrum.ApplicationCommand

  @allowed_event_names %{
    "cpi" => ["Core CPI m/m", "Core CPI y/y", "CPI m/m", "CPI y/y"],
    "ppi" => ["Core PPI m/m", "Core PPI y/y", "PPI m/m", "PPI y/y"],
    "retail" => [
      "Core Retail Sales m/m",
      "Core Retail Sales y/y",
      "Retail Sales m/m",
      "Retail Sales y/y"
    ],
    "prelim" => ["Prelim UoM Consumer Sentiment", "Prelim UoM Inflation Expectations"],
    "nonfarm" => ["ADP Non-Farm Employment Change", "Non-Farm Employment Change"],
    "unemployment" => ["Unemployment Claims", "Unemployment Rate"],
    "ism" => ["ISM Manufacturing PMI", "ISM Services PMI"],
    "fomc" => ["FOMC Economic Projections", "FOMC Statement", "FOMC Press Conference"],
    "other" => ["Average Hourly Earnings m/m", "Federal Funds Rate", "ECB Press Conference"]
  }

  @impl true
  def description, do: "Lấy dữ liệu từ 1 đến 6 tháng gần nhất"

  @impl true
  def type, do: :slash

  @impl true
  def command(interaction) do
    {:ok, cpi_data} = Cachex.get(:cache, "cpi_data")

    [
      %ApplicationCommandInteractionDataOption{
        name: "month",
        value: month_to_cpi
      },
      %ApplicationCommandInteractionDataOption{
        name: "type",
        value: type_to_get_data
      },
      %ApplicationCommandInteractionDataOption{
        name: "currency",
        value: currency_to_get_data
      }
    ] = interaction.data.options

    type_to_get_data = String.downcase(type_to_get_data)
    currency_to_get_data = String.upcase(currency_to_get_data)

    if trunc(month_to_cpi) < 1 or trunc(month_to_cpi) > 12 do
      error_embed =
        %Nostrum.Struct.Embed{}
        |> put_description("CPI chỉ hỗ trợ thời gian từ 1 đến 12 tháng gần nhất")
        |> put_color(0xEB4034)

      [embeds: [error_embed], ephemeral?: true]
    else
      time_to_get_cpi =
        localtime_now()
        |> DateTime.to_date()
        |> Date.beginning_of_month()
        |> Date.shift(month: -trunc(month_to_cpi))

      time_end_to_get_cpi =
        localtime_now() |> DateTime.to_date() |> Date.beginning_of_month() |> Date.shift(day: -1)

      cpi_data_embed =
        Enum.filter(cpi_data, fn event ->
          compare_time_begin = Date.compare(event.date, time_to_get_cpi)
          compare_time_end = Date.compare(event.date, time_end_to_get_cpi)

          (compare_time_begin == :gt or compare_time_begin == :eq) and
            (compare_time_end == :lt or compare_time_end == :eq)
        end)
        |> filter_events(type_to_get_data, currency_to_get_data)
        |> Enum.chunk_every(9)
        |> Enum.map(&create_embed/1)

      {:ok, _} =
        Cachex.put(
          :cache,
          "cpi_interaction:#{interaction.id}",
          %{
            data: cpi_data_embed,
            current_page: 0
          },
          expire: :timer.minutes(30)
        )

      if cpi_data_embed != [] do
        [first_pagination_embed | _] = cpi_data_embed

        first_page_button = interaction_button("<<", "first_prev", style: 3, disabled: true)
        prev_page_button = interaction_button("<", "prev_page", style: 3, disabled: true)

        pagination_info_button =
          interaction_button("1 / #{length(cpi_data_embed)}", "page_info", style: 2, disabled: true)

        next_page_button =
          interaction_button(">", "next_page", style: 3, disabled: length(cpi_data_embed) == 1)

        last_page_button =
          interaction_button(">>", "last_next", style: 3, disabled: length(cpi_data_embed) == 1)

        action_row =
          action_row([
            first_page_button,
            prev_page_button,
            pagination_info_button,
            next_page_button,
            last_page_button
          ])

        [embeds: [first_pagination_embed], components: [action_row]]
      else
        response_embed =
          %Nostrum.Struct.Embed{}
          |> put_title("Forex CPI Data")
          |> put_color(0x4285F4)
          |> put_description("Không có data.")

        [embeds: [response_embed], ephemeral?: true]
      end
    end
  end

  defp create_embed([]) do
    %Nostrum.Struct.Embed{}
    |> put_title("Forex Data")
    |> put_color(0x4285F4)
    |> put_description("Không có data.")
  end

  defp create_embed(events) do
    %Nostrum.Struct.Embed{}
    |> put_title("Forex CPI Data")
    |> put_color(0x4285F4)
    |> put_events(events)
  end

  defp put_events(embed, []) do
    embed |> put_description("Không có data.")
  end

  defp put_events(embed, events) do
    events
    |> Enum.reduce(embed, fn event, accumulate_embed ->
      date = event.date |> Date.to_string() |> String.replace("-", "/")

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
          "#{impact_emoji} #{event.impact} ([Details](#{event.event_url}))",
          "```Actual: #{event.actual}",
          "Forecast: #{event.forecast}",
          "Previous: #{event.previous}```"
        ]
        |> Enum.join("\n")

      accumulate_embed
      |> put_field(
        "`#{date} #{event.time}` #{currency_emoji} #{event.currency} - #{event.event_name}",
        field_event,
        true
      )
    end)
  end

  @impl true
  def options do
    [
      %{
        name: "month",
        description: "Các tháng để lấy dữ liệu trở về trước",
        required: true,
        type: :number
      },
      %{
        name: "type",
        description: "Loại dữ liệu",
        required: true,
        type: :string
      },
      %{
        name: "currency",
        description: "Loại tiền tệ",
        required: true,
        type: :string
      }
    ]
  end

  defp filter_events([], _, _), do: []

  defp filter_events(events, type_to_get_data, currency_to_get_data) do
    events
    |> Enum.filter(fn event ->
      event.event_name in Map.get(@allowed_event_names, type_to_get_data, [])
    end)
    |> Enum.filter(fn event ->
      event.currency == currency_to_get_data
    end)
  end
end
