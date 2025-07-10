defmodule ForexCalendarWeb.UserSettingsLive do
  use ForexCalendarWeb, :live_view

  alias ForexCalendar.Servers
  alias ForexCalendar.Servers.Server

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-end mb-6">
        <.button phx-click={show_modal("add-server-modal")} class="flex items-center gap-2 !text-sm">
          <.icon name="hero-plus" class="h-4 w-4" /> Add Server
        </.button>
      </div>

      <div class="mb-8">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Your Discord Servers</h2>

        <div :if={Enum.empty?(@servers)} class="text-center py-12">
          <div class="text-gray-500">
            <.icon name="hero-computer-desktop" class="h-12 w-12 mx-auto mb-4 text-gray-400" />
            <p class="text-lg font-medium">No servers added yet</p>
            <p class="text-sm mt-1">Add your first Discord server to get started</p>
          </div>
        </div>

        <div :if={!Enum.empty?(@servers)} class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div
            :for={server <- @servers}
            class="bg-white rounded-lg shadow-md border border-gray-200 p-6 hover:shadow-lg transition-shadow duration-200"
          >
            <% server_guild = get_discord_guild(server) %>
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <h3 class="text-lg font-semibold text-gray-900">{server_guild.name}</h3>
              </div>

              <div class="flex space-x-2">
                <.button
                  class="!p-2 !rounded-full !bg-blue-500 hover:!bg-blue-600 !flex !items-center !justify-center"
                  phx-click={JS.navigate(~p"/users/settings/#{server.id}")}
                >
                  <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
                </.button>
                <.button
                  class="!p-2 !rounded-full !bg-red-500 hover:!bg-red-600 !flex !items-center !justify-center"
                  phx-click="delete_server"
                  phx-value-id={server.id}
                  data-confirm="Are you sure you want to remove this server?"
                >
                  <.icon name="hero-trash" class="h-4 w-4" />
                </.button>
              </div>
            </div>

            <div class="space-y-2 text-sm text-gray-600">
              <div class="flex justify-between">
                <span>Added:</span>
                <% inserted_time = DateTime.shift_zone!(server.inserted_at, "Asia/Ho_Chi_Minh") %>
                <span>{Calendar.strftime(inserted_time, "%Y-%m-%d %H:%M")}</span>
              </div>
              <div class="flex justify-between">
                <span>Guild ID:</span>
                <code>{server.guild_id}</code>
              </div>
            </div>
          </div>
        </div>
      </div>

      <.modal
        id="add-server-modal"
        on_cancel={hide_modal("add-server-modal")}
        show={@show_add_server_modal}
      >
        <div class="space-y-6">
          <div>
            <h2 class="text-lg font-semibold text-gray-900">Add New Server</h2>
            <p class="mt-1 text-sm text-gray-600">
              Enter the Guild ID of the Discord server you want to add.
            </p>
          </div>

          <.simple_form for={@server_form} phx-submit="create_server">
            <.input field={@server_form[:guild_id]} type="number" label="Guild ID" required />

            <div class="flex justify-end space-x-1">
              <.button
                type="button"
                phx-click={hide_modal("add-server-modal")}
                class="!bg-red-500 hover:!bg-red-600"
              >
                Cancel
              </.button>
              <.button type="submit" class="!px-3 !w-24">
                Add
              </.button>
            </div>
          </.simple_form>
        </div>
      </.modal>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    servers = if user, do: Servers.list_servers(user.id), else: []
    server_changeset = Server.changeset(%Server{}, %{})

    {:ok,
     socket
     |> assign(:show_add_server_modal, false)
     |> assign(:server_form, to_form(server_changeset))
     |> assign(:servers, servers)}
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

  def handle_event("create_server", %{"server" => server_params}, socket) do
    user = socket.assigns.current_user

    server_params = Map.put(server_params, "user_id", user.id)
    hide("add-server-modal")

    case Servers.create_server(server_params) do
      {:ok, _server} ->
        servers = Servers.list_servers(user.id)

        {:noreply,
         socket
         |> assign(:servers, servers)
         |> assign(:show_add_server_modal, false)
         |> put_flash(:info, "Server added successfully!")
         |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :server_form, to_form(changeset))}
    end
  end

  def handle_event("delete_server", %{"id" => server_id}, socket) do
    user = socket.assigns.current_user
    server = Servers.get_server!(server_id)

    case Servers.delete_server(server) do
      {:ok, _server} ->
        servers = Servers.list_servers(user.id)

        {:noreply,
         socket
         |> assign(:servers, servers)
         |> put_flash(:info, "Server removed successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove server")}
    end
  end
end
