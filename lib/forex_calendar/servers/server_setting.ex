defmodule ForexCalendar.Servers.ServerSetting do
  use Ecto.Schema
  import Ecto.Changeset

  alias ForexCalendar.Servers.Server

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "server_settings" do
    field :announcement_channel_id, :string
    belongs_to :server, Server

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server_setting, attrs) do
    server_setting
    |> cast(attrs, [:server_id, :announcement_channel_id])
    |> validate_required([:server_id])
    |> validate_discord_channel(:announcement_channel_id)
    |> foreign_key_constraint(:server_id)
  end

  defp validate_discord_channel(changeset, field) do
    channel_id_params = get_field(changeset, field)

    if channel_id_params do
      channel_id = channel_id_params |> String.to_integer()

      case Nostrum.Api.Channel.get(channel_id) do
        {:ok, _discord_channel} ->
          changeset

        {:error, _reason} ->
          changeset
          |> add_error(
            field,
            "Discord channel does not exist or is not accessible with this channel ID."
          )
      end
    else
      changeset
    end
  end
end
