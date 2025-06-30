defmodule ForexCalendar.Servers.ServerSetting do
  use Ecto.Schema
  import Ecto.Changeset

  alias ForexCalendar.Servers.Server

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "server_settings" do
    belongs_to :server, Server

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server_setting, attrs) do
    server_setting
    |> cast(attrs, [:server_id])
    |> validate_required([:server_id])
    |> foreign_key_constraint(:server_id)
  end
end
