defmodule ForexBot.InteractionHandler do
  alias Nostrum.Api.Interaction

  alias ForexBot.Repo
  import Nostrum.Struct.Embed

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

  defp perform_job_immediately(job) do
    Oban.cancel_job(job)

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
