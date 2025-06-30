defmodule ForexCalendar.Repo.Migrations.CreateServersAndServerSettings do
  use Ecto.Migration

  def change do
    # Create servers table
    create table(:servers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:servers, [:user_id])

    # Create server_settings table
    create table(:server_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :server_id, references(:servers, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:server_settings, [:server_id])
  end
end
