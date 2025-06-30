defmodule ForexCalendar.Repo.Migrations.AddGuildIdToServers do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :guild_id, :string, null: false
    end

    create unique_index(:servers, [:guild_id])
  end
end
