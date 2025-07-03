defmodule ForexCalendar.Repo.Migrations.AddAnnouncementChannelIdToServerSettings do
  use Ecto.Migration

  def change do
    alter table(:server_settings) do
      add :announcement_channel_id, :string
    end
  end
end
