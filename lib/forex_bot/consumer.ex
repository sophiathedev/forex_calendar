defmodule ForexBot.Consumer do
  @behaviour Nostrum.Consumer

  def handle_event({:READY, _ready, _ws_state}) do
    :logger.info("Bot is ready!")
    guild_id = Application.get_env(:forex_bot, :guild_id)

    slashs = [
      Nosedrum.Storage.Dispatcher.add_command("today", ForexBot.Slash.Today, guild_id),
      Nosedrum.Storage.Dispatcher.add_command("announce", ForexBot.Slash.Announce, guild_id),
      Nosedrum.Storage.Dispatcher.add_command("cpi", ForexBot.Slash.Cpi, guild_id)
    ]

    slashs
    |> Enum.each(fn slash ->
      case slash do
        {:ok, cmd} -> :logger.info("Registered command: #{cmd.name}")
        {:error, reason} -> :logger.error("Failed to register command: #{inspect(reason)}")
      end
    end)
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) when interaction.type == 2 do
    Nosedrum.Storage.Dispatcher.handle_interaction(interaction)
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) when interaction.type == 3 do
    ForexBot.InteractionHandler.handle_event(interaction.data.custom_id, interaction)
  end

  def handle_event(_), do: :ok
end
