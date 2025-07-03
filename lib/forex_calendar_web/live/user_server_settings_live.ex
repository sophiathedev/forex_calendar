defmodule ForexCalendarWeb.UserServerSettingsLive do
  use ForexCalendarWeb, :live_view

  alias ForexCalendar.Servers
  alias ForexCalendar.Servers.{Server, ServerSetting}

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="mb-6">
        <.link navigate={~p"/users/settings"} class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-800">
          <.icon name="hero-arrow-left" class="h-4 w-4" />
          Back to Servers
        </.link>
      </div>

      <div class="bg-white rounded-lg shadow-md border border-gray-200 p-6">
        <div class="mb-6">
          <div class="flex items-center gap-3 mb-2">
            <h1 class="text-2xl font-bold text-gray-900">{@server_guild.name}</h1>
          </div>
          <p class="text-gray-600">Configure settings for this Discord server</p>
        </div>

        <div class="space-y-6">
          <%= if @server_channel do %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-2xl p-4">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-sm font-medium text-yellow-800">Channel Actions for <span class="font-bold">{@server_channel.name}</span> channel</h3>
                  <p class="text-sm text-yellow-700 mt-1">
                    Manage messages in the announcement channel
                  </p>
                </div>
                <.button
                  type="button"
                  phx-click="bulk_delete_messages"
                  data-confirm="Are you sure you want to delete all messages in the announcement channel? This action cannot be undone."
                  class="!bg-red-600 hover:!bg-red-700 !text-white !rounded-xl"
                >
                  <.icon name="hero-trash" class="h-4 w-4 mr-2" />
                  Bulk Delete Messages
                </.button>
              </div>
            </div>
          <% end %>

          <.simple_form for={@settings_form} phx-submit="save_settings">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Announcement Channel
                </label>
                <.input
                  field={@settings_form[:announcement_channel_id]}
                  type="text"
                  placeholder="Enter channel ID..."
                  class="w-full"
                />
                <p class="mt-2 text-sm text-gray-500">
                  Enter the Discord channel ID where forex calendar announcements will be posted
                </p>
              </div>
            </div>

            <div class="flex justify-end space-x-3 pt-4">
              <.button type="submit" class="!px-6">
                Save Settings
              </.button>
            </div>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"server_id" => server_id}, _session, socket) do
    user = socket.assigns.current_user

    # Get server and verify ownership
    server = Servers.get_server!(server_id)

    if server.user_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this server")
       |> push_navigate(to: ~p"/users/settings/")}
    else
      # Get or create server settings
      server_setting = Servers.get_server_settings(server.id) || %ServerSetting{server_id: server.id}

      # Get Discord guild information
      server_guild = get_discord_guild(server)
      settings_changeset = ServerSetting.changeset(server_setting, %{})
      server_setting_channel_id = server_setting.announcement_channel_id
      server_setted_channel = if server_setting_channel_id, do: get_discord_guild_channel(server_setting_channel_id), else: nil

      {:ok,
       socket
       |> assign(:server, server)
       |> assign(:server_guild, server_guild)
       |> assign(:server_setting, server_setting)
       |> assign(:server_channel, server_setted_channel)
       |> assign(:settings_form, to_form(settings_changeset))}
    end
  end

  defp get_discord_guild(server) do
    {:ok, exist_cached_guild} = Cachex.exists?(:cache, "guild#{server.guild_id}")

    if not exist_cached_guild do
      %Server{guild_id: guild_id} = server

      {:ok, guild} = Nostrum.Api.Guild.get(String.to_integer(guild_id))
      {:ok, true} = Cachex.put(:cache, "guild#{server.guild_id}", guild, expire: :timer.hours(1))

      guild
    else
      {:ok, guild} = Cachex.get(:cache, "guild#{server.guild_id}")
      guild
    end
  end

  defp get_discord_guild_channel(channel_id) do
    {:ok, exist_cached_channel} = Cachex.exists?(:cache, "channel#{channel_id}")

    if not exist_cached_channel do
      {:ok, channel} = Nostrum.Api.Channel.get(String.to_integer(channel_id))
      {:ok, true} = Cachex.put(:cache, "channel#{channel_id}", channel, expire: :timer.hours(1))

      channel
    else
      {:ok, channel} = Cachex.get(:cache, "channel#{channel_id}")

      channel
    end
  end

  def handle_event("save_settings", %{"server_setting" => setting_params}, socket) do
    server_setting = socket.assigns.server_setting

    case server_setting.id do
      nil ->
        setting_params = Map.put(setting_params, "server_id", socket.assigns.server.id)
        case Servers.create_server_settings(setting_params) do
          {:ok, _server_setting} ->
            {:noreply,
             socket
             |> put_flash(:info, "Settings saved successfully!")
             |> push_navigate(to: ~p"/users/settings")}

          {:error, changeset} ->
            {:noreply, assign(socket, :settings_form, to_form(changeset))}
        end

      _id ->
        case Servers.update_server_settings(server_setting, setting_params) do
          {:ok, _server_setting} ->
            {:noreply,
             socket
             |> put_flash(:info, "Settings updated successfully!")
             |> push_navigate(to: ~p"/users/settings/#{socket.assigns.server.id}")}

          {:error, changeset} ->
            {:noreply, assign(socket, :settings_form, to_form(changeset))}
        end
    end
  end

  def handle_event("bulk_delete_messages", _params, socket) do
    channel_id = socket.assigns.server_setting.announcement_channel_id |> String.to_integer()
    {:ok, messages} = Nostrum.Api.Channel.messages(channel_id, 100)

    messages = messages |> Enum.map(&(&1.id))

    case Nostrum.Api.Channel.bulk_delete_messages(channel_id, messages) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Bulk delete messages action completed successfully.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to bulk delete messages: #{inspect(reason)}")}
    end
  end
end
