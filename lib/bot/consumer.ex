defmodule Bot.Consumer do
  require Logger
  @behaviour Nostrum.Consumer
  @guild_id System.fetch_env!("GUILD_ID")

  def handle_event({:READY, _ready, _ws_state}) do
    slash_command = [

    ]

    slash_command |> Enum.each(fn slash ->
      case slash do
        {:ok, cmd} -> Logger.info("Registered command: #{cmd.name}")
        {:error, reason} -> Logger.error("Failed to register command: #{inspect(reason)}")
      end
    end)
  end

  def handle_event(_), do: :ok
end
