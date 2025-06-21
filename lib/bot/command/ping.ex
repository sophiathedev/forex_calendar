defmodule Bot.Command.Ping do
  import Nostrum.Struct.Embed
  alias Nostrum.Struct.User

  @behaviour Nosedrum.ApplicationCommand

  @impl true
  def description, do: "Get bot latency and informations"

  @impl true
  def type, do: :slash

  @impl true
  def command(interaction) do
    [embeds: [embed_info(interaction)], ephemeral?: true]
  end

  defp embed_info(interaction) do
    avatar_url = User.avatar_url(interaction.user, "png")

    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Pong!")
      |> put_author(User.full_name(interaction.user), avatar_url, avatar_url)
      |> put_color(0x4285F4)
      |> put_footer("Powered by Elixir Nostrum")
      |> put_field("Elixir version", "`#{Application.spec(:elixir, :vsn)}`", true)
      |> put_field("Version", "`#{Application.spec(:forex_calendar, :vsn)}`", true)
      |> put_field("Ping", "`#{round(get_average_latency())}ms`", false)

    embed
  end

  defp get_average_latency do
    latencies = Nostrum.Util.get_all_shard_latencies() |> Map.values()
    Enum.sum(latencies) / length(latencies)
  end
end
