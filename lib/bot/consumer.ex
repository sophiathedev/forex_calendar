defmodule Bot.Consumer do
  require Logger
  @behaviour Nostrum.Consumer

  def handle_event({:READY, _ready, _ws_state}) do
    guild_id = Application.get_env(:forex_calendar, :guild_id)

    slash_command = [
      Nosedrum.Storage.Dispatcher.add_command("ping", Bot.Command.Ping, guild_id),
      Nosedrum.Storage.Dispatcher.add_command("today", Bot.Command.Today, guild_id)
    ]

    slash_command
    |> Enum.each(fn slash ->
      case slash do
        {:ok, cmd} -> Logger.info("Registered command: #{cmd.name}")
        {:error, reason} -> Logger.error("Failed to register command: #{inspect(reason)}")
      end
    end)
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) when interaction.type == 2 do
    Nosedrum.Storage.Dispatcher.handle_interaction(interaction)
  end

  def handle_event(_), do: :ok
end
