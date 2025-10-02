defmodule ForexBot.InteractionHandler do
  alias Nostrum.Api.Interaction

  alias ForexBot.Repo
  import Nostrum.Struct.Embed

  import Nostrum.Struct.Component.Button, only: [interaction_button: 3]
  import Nostrum.Struct.Component.SelectMenu, only: [select_menu: 2]
  import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]
  import ForexBot.Utils, only: [localtime_now: 0]
  import ForexBot.Slash.Data, only: [create_embed: 1]

  @allowed_currencies ["USD", "EUR", "GBP", "JPY"]
  def handle_event("event_for_data", interaction) do
    caching_key = "interaction:data:#{interaction.message.interaction.id}"
    if Cachex.exists?(:cache, caching_key) == {:ok, true} do
      {:ok, interaction_data} = Cachex.get(:cache, caching_key)

      # Use pattern matching because it always has one value
      [event_name_for_data] = interaction.data.values
      interaction_data = interaction_data |> Map.put(:event_name, event_name_for_data)
      {:ok, true} = Cachex.put(:cache, caching_key, interaction_data, expire: :timer.hours(1))

      currency_selection_menu = select_menu("currency_for_data",
        options: @allowed_currencies |> Enum.map(&%{label: &1, value: &1}),
        placeholder: "Lựa chọn loại tiền tệ",
        min_values: 1,
        max_values: 1
      )
      action_row = action_row(components: [currency_selection_menu])

      Nostrum.Api.Interaction.create_response(interaction, %{
        type: 7,
        data: %{
          components: [action_row],
        }
      })
    else
      expired_interaction_response(interaction)
    end
  end

  def handle_event("currency_for_data", interaction) do
    caching_key = "interaction:data:#{interaction.message.interaction.id}"
    if Cachex.exists?(:cache, caching_key) == {:ok, true} do
      {:ok, interaction_data} = Cachex.get(:cache, caching_key)
      [selected_currency] = interaction.data.values
      interaction_data = interaction_data |> Map.put(:currency, selected_currency)

      {:ok, data} = Cachex.get(:cache, "cpi_data")
      time_start_get_data =
        localtime_now()
        |> DateTime.to_date()
        |> Date.beginning_of_month()
        |> Date.shift(month: -interaction_data.month)

      time_end_get_data =
        localtime_now()
        |> DateTime.to_date()
        |> Date.beginning_of_month()
        |> Date.shift(day: -1)

      data_embed =
        Enum.filter(data, fn event ->
          compare_time_begin = Date.compare(event.date, time_start_get_data)
          compare_time_end = Date.compare(event.date, time_end_get_data)

          (compare_time_begin == :gt or compare_time_begin == :eq) and (compare_time_end == :lt or compare_time_end == :eq)
        end)
        |> Enum.filter(fn event ->
          event.event_name == interaction_data.event_name and event.currency == interaction_data.currency
        end)
        |> Enum.chunk_every(9)
        |> Enum.map(&create_embed/1)


      if data_embed != [] do
        [first_pagination_embed | _] = data_embed

        first_page_button = interaction_button("<<", "first_prev", style: 3, disabled: true)
        prev_page_button = interaction_button("<", "prev_page", style: 3, disabled: true)

        pagination_info_button =
          interaction_button("1 / #{length(data_embed)}", "page_info", style: 2, disabled: true)

        next_page_button =
          interaction_button(">", "next_page", style: 3, disabled: length(data_embed) == 1)

        last_page_button =
          interaction_button(">>", "last_next", style: 3, disabled: length(data_embed) == 1)

        action_row =
          action_row([
            first_page_button,
            prev_page_button,
            pagination_info_button,
            next_page_button,
            last_page_button
          ])

        {:ok, true} = Cachex.put(
          :cache,
          "interaction:pagination:#{interaction.message.interaction.id}",
          %{data: data_embed, current_page: 0},
          expire: :timer.minutes(30)
        )

        Nostrum.Api.Interaction.create_response(interaction, %{
          type: 7,
          data: %{
            embeds: [first_pagination_embed],
            components: [action_row]
          }
        })
      else
        embed =
          %Nostrum.Struct.Embed{}
          |> put_title("Forex Data")
          |> put_color(0x4285F4)
          |> put_description("Không có data.")

        Nostrum.Api.Interaction.create_response(interaction, %{
          type: 7,
          data: %{
            embeds: [embed],
            components: [],
            ephemeral?: true
          }
        })
      end

    else
      expired_interaction_response(interaction)
    end
  end

  def handle_event("next_page", interaction) do
    {:ok, %{data: embeds, current_page: current_page}} =
      Cachex.get(:cache, "interaction:pagination:#{interaction.message.interaction.id}")

    new_pagination_number = min(current_page + 1, length(embeds) - 1)

    {:ok, _} =
      Cachex.put(:cache, "interaction:pagination:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: new_pagination_number
      })

    interaction |> create_pagination_response(embeds, new_pagination_number)
  end

  def handle_event("prev_page", interaction) do
    {:ok, %{data: embeds, current_page: current_page}} =
      Cachex.get(:cache, "interaction:pagination:#{interaction.message.interaction.id}")

    new_pagination_number = max(current_page - 1, 0)

    {:ok, _} =
      Cachex.put(:cache, "interaction:pagination:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: new_pagination_number
      })

    interaction |> create_pagination_response(embeds, new_pagination_number)
  end

  def handle_event("first_prev", interaction) do
    {:ok, %{data: embeds}} =
      Cachex.get(:cache, "interaction:pagination:#{interaction.message.interaction.id}")

    {:ok, _} =
      Cachex.put(:cache, "interaction:pagination:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: 0
      })

    interaction |> create_pagination_response(embeds, 0)
  end

  def handle_event("last_next", interaction) do
    {:ok, %{data: embeds}} =
      Cachex.get(:cache, "interaction:pagination:#{interaction.message.interaction.id}")

    last_page_number = length(embeds) - 1

    {:ok, _} =
      Cachex.put(:cache, "interaction:pagination:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: last_page_number
      })

    interaction |> create_pagination_response(embeds, last_page_number)
  end

  def handle_event("custom_announce_timestamps", interaction) do
    selected_job_id = interaction.data.values |> List.first() |> String.to_integer()

    response = %{
      type: 7,
      data: %{
        content: "",
        components: [],
        embeds: [successful_embed()],
        ephemeral?: true
      }
    }

    Repo.get(Oban.Job, selected_job_id) |> perform_job_immediately()

    Interaction.create_response(interaction, response)
  end

  defp create_pagination_response(interaction, embeds, page_number) do
    paginated_embed = embeds |> Enum.at(page_number)

    left_pagination_disabled = page_number == 0
    right_pagination_disabled = page_number == length(embeds) - 1

    first_page_button =
      interaction_button("<<", "first_prev", style: 3, disabled: left_pagination_disabled)

    prev_page_button =
      interaction_button("<", "prev_page", style: 3, disabled: left_pagination_disabled)

    pagination_info_button =
      interaction_button("#{page_number + 1} / #{length(embeds)}", "page_info",
        style: 2,
        disabled: true
      )

    next_page_button =
      interaction_button(">", "next_page", style: 3, disabled: right_pagination_disabled)

    last_page_button =
      interaction_button(">>", "last_next", style: 3, disabled: right_pagination_disabled)

    action_row =
      action_row([
        first_page_button,
        prev_page_button,
        pagination_info_button,
        next_page_button,
        last_page_button
      ])

    Nostrum.Api.Interaction.create_response(interaction, %{
      type: 7,
      data: %{
        embeds: [paginated_embed],
        components: [action_row]
      }
    })
  end

  defp perform_job_immediately(job) do
    # Oban.cancel_job(job)

    job_module = String.to_existing_atom("Elixir." <> job.worker)

    job.args
    |> job_module.new()
    |> Oban.insert()
  end

  defp successful_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("Thông báo !")
    |> put_description("Thao tác thành công !.")
    |> put_color(0x32A852)
    |> put_footer("Powered by Elixir Nostrum.")
  end

  defp expired_interaction_response(interaction) do
    error_embed = %Nostrum.Struct.Embed{}
    |> put_description("Tương tác đã hết hạn, vui lòng thử lại.")
    |> put_color(0xEB4034)

    Nostrum.Api.Interaction.create_response(interaction, %{
      type: 4,
      data: %{
        embeds: [error_embed],
        components: [],
        ephemeral?: true
      }
    })
  end
end
