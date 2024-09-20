defmodule KioskWeb.NervesHubStatusLive do
  @moduledoc """
  TODO: docs
  """
  use KioskWeb, :live_view

  # alias Phoenix.LiveView.JS
  # import KioskWeb.Gettext
  require Logger

  @doc """
  TODO: doc
  """
  def mount(_, _, socket) do
    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Kiosk.PubSub, "nerves_hub_manager")
        Kiosk.NetworkManager.subscribe()

        socket =
          socket
          |> assign_info_blank()
          |> assign_info()

        refresh(socket)
        socket
      else
        assign_info_blank(socket)
      end

    {:ok, socket}
  end

  def handle_info(:update_status, socket) do
    socket = assign_info(socket)

    refresh(socket)
    {:noreply, socket}
  end

  def handle_info(:change, socket) do
    socket =
      socket
      |> assign(network_status: NetworkManager.status())

    {:noreply, socket}
  end

  def handle_info({:link, status}, socket) do
    dbg(status)

    socket =
      socket
      |> assign_link_status()
      |> assign_info()

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp assign_link_status(socket) do
    socket
    |> assign(link_status: Kiosk.NervesHubManager.status())
  end

  defp assign_info_blank(socket) do
    socket
    |> assign(
      link_status: Kiosk.NervesHubManager.status(),
      # link_status: %{starting?: false, started?: true},
      network_status: nil,
      status: :idle,
      connected?: false,
      console_active?: false
    )
  end

  defp assign_info(socket) do
    if socket.assigns.link_status.started? do
      socket
      |> assign(
        status: nerves_hub_link_status(),
        # status: :idle,
        # status: {:fwup_error, "There was a problem updating this device."},
        # status: {:updating, 33},
        # status: :update_rescheduled,
        connected?: nerves_hub_link_connected?(),
        network_status: NetworkManager.status() |> IO.inspect(label: "network_status"),
        # connected?: false,
        # connected?: true,
        # console_active?: NervesHubLink.console_active?(),
        console_active?: nerves_hub_link_console_active?()
      )
    else
      socket
    end
  catch
    e, f ->
      Logger.error("Some error: #{inspect(e)} #{inspect(f)}")
      socket
  end

  defp nerves_hub_link_status() do
    try do
      NervesHubLink.status()
    catch
      _, _ ->
        :idle
    end
  end

  defp nerves_hub_link_connected?() do
    try do
      NervesHubLink.connected?()
    catch
      _, _ ->
        false
    end
  end

  defp nerves_hub_link_console_active?() do
    try do
      NervesHubLink.console_active?()
    catch
      _, _ ->
        false
    end
  end

  defp refresh(%{assigns: %{connected?: connected?, status: status}}) do
    time =
      case {connected?, status} do
        {false, _} ->
          200

        {true, :idle} ->
          5000

        {true, {:updating, _}} ->
          200

        _ ->
          1000
      end

    Process.send_after(self(), :update_status, time)
  end

  def render(assigns) do
    ~H"""
    <!-- only show this if something is actually happening -->
    <div id="nerves-hub-status-indicator">
    <div class="fixed top-2 right-2 text-xs flex gap-1">
      <svg class="w-4" xmlns="http://www.w3.org/2000/svg" x="0" y="0" viewBox="0 0 187.98 152.5" style="enable-background:new 0 0 187.98 152.5" xml:space="preserve"><style>.st0{fill:#33647e}.st1{fill:#42a7c6}.st2{fill:#24272a}.st3{fill:#fff}.st4{fill:#672f25}.st5{fill:#aa2d29}</style><path d="M44.97 0h-36C4.02 0 0 4.02 0 8.97v134.57c0 4.95 4.01 8.97 8.97 8.97h30.01c4.95 0 8.97-4.01 8.97-8.97v-5.39c0-4.95-4.01-8.97-8.97-8.97h-6.69c-4.95 0-8.97-4.01-8.97-8.97V32.29c0-4.95 4.01-8.97 8.97-8.97h6.34c1.89 0 3.73.6 5.26 1.7l83.13 60.19c5.93 4.29 14.23.06 14.23-7.26v-3.83c0-2.83-1.34-5.49-3.6-7.19L50.33 1.78A9.006 9.006 0 0 0 44.97 0z"/><path d="M143.01 152.5h36c4.95 0 8.97-4.01 8.97-8.97V8.97c0-4.95-4.01-8.97-8.97-8.97H149c-4.95 0-8.97 4.01-8.97 8.97v5.39c0 4.95 4.01 8.97 8.97 8.97h6.69c4.95 0 8.97 4.01 8.97 8.97v87.91c0 4.95-4.01 8.97-8.97 8.97h-6.34c-1.89 0-3.73-.6-5.26-1.7l-83.13-60.2c-5.93-4.29-14.23-.06-14.23 7.26v3.83c0 2.83 1.34 5.49 3.6 7.19l87.31 65.17a9.048 9.048 0 0 0 5.37 1.77z"/></svg>
      <%= case @status do %>
        <% {:fwup_error, error} -> %>
          <div class="rounded bg-red-600 text-white p-1 px-2">Error: <%= error %></div>
        <% {:updating, progress} -> %>
          <div class="animate-pulse w-8"><div class="h-4 bg-lime-500" style={"width: #{progress}%"}></div></div>

        <% :update_rescheduled -> %>
          <div class="animate-pulse " title="An update has been scheduled">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4 animate-bounce">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3" />
            </svg>
          </div>
        <% :idle -> %>
          <div :if={not @connected?} class="animate-pulse" title="This device is not connected to the server">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4 align-center">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
            </svg>
          </div>

          <div :if={@connected?} class="" title="This device is connected to NervesHub">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4 align-center">
              <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
            </svg>
          </div>

          <div :if={@console_active?}>
              <div class="p-4 px-8">A remote service console is active.</div>
          </div>
      <% end %>

      <pre><%= inspect(@network_status, pretty: true) %></pre>
    </div>
    </div>
    """
  end
end
