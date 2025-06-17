defmodule Bot.Command.Ping do
  import Nostrum.Struct.Embed
  alias Nostrum.Struct.User

  @behaviour Nosedrum.ApplicationCommand

  @impl true
  def description, do: "Get bot latency and informations"

  @impl true
  def type, do: :slash

  @impl true
  def command(_interaction) do
    latency = Nostrum.Util.get_all_shard_latencies() |> Map.values
    latency = Enum.sum(latency) / length(latency)
    [content: ":ping_pong: Pong! Latency: #{round(latency)}ms"]
  end

  defp embed_info(interaction) do
    avatar_url = User.avatar_url(interaction.user, "png")
    embed = %Nostrum.Struct.Embed{} |> put_author("#{interaction.member.nick}", avatar_url, avatar_url) |> put_thumbnail(avatar_url)
  end
end
