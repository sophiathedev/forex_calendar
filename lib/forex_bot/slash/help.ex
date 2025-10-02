defmodule ForexBot.Slash.Help do
  import Nostrum.Struct.Embed

  @behaviour Nosedrum.ApplicationCommand

  @impl true
  def description, do: "Hiển thị hướng dẫn sử dụng bot"

  @impl true
  def type, do: :slash

  @impl true
  def command(_interaction) do
    help_embed = %Nostrum.Struct.Embed{}
    |> put_title("Hướng dẫn sử dụng bot")
    |> put_field("`/data month:<1-12>`", "Lấy dữ liệu kinh tế trong vòng 1 đến 6 tháng gần nhất.", false)
    |> put_field("Ví dụ", "```/data month:3```", false)
    |> put_color(0x32A852)

    [embeds: [help_embed], ephemeral?: true]
  end
end
