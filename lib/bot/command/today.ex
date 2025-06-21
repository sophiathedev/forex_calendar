defmodule Bot.Command.Today do
  @behaviour Nosedrum.ApplicationCommand

  @impl true
  def description, do: "Get today's Forex events"

  @impl true
  def type, do: :slash

  @impl true
  def command(_interaction) do
  end
end
