defmodule ForexBot.Slash.Announce do
  @behaviour Nosedrum.ApplicationCommand

  import Ecto.Query
  import Nostrum.Struct.Embed
  alias ForexBot.Repo

  @impl true
  def description, do: "Lấy các tin đặc biệt trong ngày hiện tại"

  @impl true
  def type, do: :slash

  @impl true
  def command(_interaction) do
    today =
      DateTime.now("Asia/Ho_Chi_Minh")
      |> elem(1)
      |> DateTime.to_date()
    today_begin_of_day = DateTime.new!(today, ~T[00:00:00], "Asia/Ho_Chi_Minh") |> DateTime.shift_zone!("Etc/UTC")
    today_end_of_day = DateTime.new!(today, ~T[23:59:59.999999], "Asia/Ho_Chi_Minh") |> DateTime.shift_zone!("Etc/UTC")

    query =
      from(j in Oban.Job,
      where: j.state in ["scheduled", "available"],
      where: j.scheduled_at >= ^today_begin_of_day and j.scheduled_at <= ^today_end_of_day)

    jobs = Repo.all(query)
    case jobs do
      [] -> response_no_jobs_found()
      _ -> response_action_row(jobs)
    end
  end

  defp response_action_row(jobs) do
    all_timestamps = jobs |> Enum.map(fn job ->
      %{label: job.args["timestamp"], value: job.id}
    end)

    selection_menu = Nostrum.Struct.Component.SelectMenu.select_menu(
      "custom_announce_timestamps",
      options: all_timestamps,
      placeholder: "Lựa chọn mốc thời gian",
      min_values: 1,
      max_values: 1
    )

    action_row = Nostrum.Struct.Component.ActionRow.action_row(components: [selection_menu])

    [content: "Vui lòng đối chiếu với các mốc thời gian ở trên, để chọn ra thời gian tin mà muốn thông báo **ngay lập tức**:", components: [action_row], ephemeral?: true]
  end

  defp response_no_jobs_found do
    embeds = %Nostrum.Struct.Embed{}
    |> put_title("Thông báo !")
    |> put_description("Không tìm thấy tin nào được lên lịch trong ngày hôm nay.")
    |> put_color(0xFF0000)
    |> put_footer("Powered by Elixir Nostrum.")

    [embeds: [embeds], ephemeral?: true]
  end

end
