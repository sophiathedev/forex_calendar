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
    |> put_field("`/data month:<1-6> type:<type>`", "Lấy dữ liệu kinh tế trong vòng 1 đến 6 tháng gần nhất.", false)
    |> put_field("Ví dụ", "```/data month:3 type:cpi currency:usd\n/data month:2 type:prelim currency:usd\n/data month:6 type:unemployment currency:usd\n/data month:4 type:other currency:usd```", false)
    |> put_color(0x32A852)

    params_help_embed = %Nostrum.Struct.Embed{}
    |> put_title("Các kiểu dữ liệu (danh cho tham số type)")
    |> put_field("`cpi`", "Chỉ số giá tiêu dùng (Consumer Price Index)", true)
    |> put_field("`ppi`", "Chỉ số giá sản xuất (Producer Price Index)", true)
    |> put_field("`prelim`", "Dữ liệu sơ bộ (Preliminary Data)", true)
    |> put_field("`retail`", "Doanh số bán lẻ (Retail Sales)", true)
    |> put_field("`unemployment`", "Tỷ lệ thất nghiệp (Unemployment Rate)", true)
    |> put_field("`nonfarm`", "Thay đổi việc làm phi nông nghiệp (Non-Farm Employment Change)", true)
    |> put_field("`ism`", "Chỉ số quản lý thu mua (ISM)", true)
    |> put_field("`fomc`", "Dữ liệu từ cuộc họp", true)
    |> put_field("`other`", "Dữ liệu khác, bao gồm:\n+ Average Hourly Earnings m/m\n+ Federal Funds Rate\n+ ECB Press Conference", true)
    |> put_color(0x32A852)

    currency_param_help_embed = %Nostrum.Struct.Embed{}
    |> put_title("Tham số `currency`")
    |> put_field("`USD`", "Hiển thị các tin của Dollar Mỹ :flag_us:", false)
    |> put_field("`EUR`", "Hiển thị các tin của Euro :flag_eu:", false)
    |> put_field("`GBP`", "Hiển thị các tin của Bảng Anh :flag_gb:", true)
    |> put_field("`JPY`", "Hiển thị các tin của Yen Nhật :flag_jp:", false)
    |> put_color(0x32A852)

    [embeds: [help_embed, params_help_embed, currency_param_help_embed], ephemeral?: true]
  end
end
