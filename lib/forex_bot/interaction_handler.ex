defmodule ForexBot.InteractionHandler do
  alias Nostrum.Api.Interaction

  alias ForexBot.Repo
  import Nostrum.Struct.Embed

  import Nostrum.Struct.Component.Button, only: [interaction_button: 3]
  import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]

  def handle_event("next_page", interaction) do
    {:ok, %{data: embeds, current_page: current_page}} =
      Cachex.get(:cache, "cpi_interaction:#{interaction.message.interaction.id}")

    new_pagination_number = min(current_page + 1, length(embeds) - 1)

    {:ok, _} =
      Cachex.put(:cache, "cpi_interaction:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: new_pagination_number
      })

    interaction |> create_pagination_response(embeds, new_pagination_number)
  end

  def handle_event("prev_page", interaction) do
    {:ok, %{data: embeds, current_page: current_page}} =
      Cachex.get(:cache, "cpi_interaction:#{interaction.message.interaction.id}")

    new_pagination_number = max(current_page - 1, 0)

    {:ok, _} =
      Cachex.put(:cache, "cpi_interaction:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: new_pagination_number
      })

    interaction |> create_pagination_response(embeds, new_pagination_number)
  end

  def handle_event("first_prev", interaction) do
    {:ok, %{data: embeds}} =
      Cachex.get(:cache, "cpi_interaction:#{interaction.message.interaction.id}")

    {:ok, _} =
      Cachex.put(:cache, "cpi_interaction:#{interaction.message.interaction.id}", %{
        data: embeds,
        current_page: 0
      })

    interaction |> create_pagination_response(embeds, 0)
  end

  def handle_event("last_next", interaction) do
    {:ok, %{data: embeds}} =
      Cachex.get(:cache, "cpi_interaction:#{interaction.message.interaction.id}")

    last_page_number = length(embeds) - 1

    {:ok, _} =
      Cachex.put(:cache, "cpi_interaction:#{interaction.message.interaction.id}", %{
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
    dbg(page_number)
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
end
