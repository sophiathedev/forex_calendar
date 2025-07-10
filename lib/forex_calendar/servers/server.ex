defmodule ForexCalendar.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset

  alias ForexCalendar.Accounts.User
  alias ForexCalendar.Servers.ServerSetting

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "servers" do
    field :guild_id, :string
    belongs_to :user, User
    has_one :server_setting, ServerSetting

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:user_id, :guild_id])
    |> validate_required([:user_id, :guild_id])
    |> unique_constraint(:guild_id)
    |> validate_discord_server(:guild_id)
    |> foreign_key_constraint(:user_id)
  end

  def validate_discord_server(changeset, field) do
    guild_id_params = get_field(changeset, field)

    if guild_id_params do
      guild_id = guild_id_params |> String.to_integer()

      case Nostrum.Api.Guild.get(guild_id) do
        {:ok, _discord_server} ->
          changeset

        {:error, _reason} ->
          changeset
          |> add_error(
            field,
            "Discord server does not exists or is not accessible with this guild ID."
          )
      end
    else
      changeset
    end
  end
end
