defmodule KioskWeb.NervesHubStatusLive do
  @moduledoc """
  TODO: docs
  """
  use KioskWeb, :live_view

  alias Phoenix.LiveView.JS
  import KioskWeb.Gettext

  @doc """
  TODO: doc
  """
  def mount(_, _, socket) do
    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Kiosk.PubSub, "nerves_hub_manager")

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

  def handle_info({:link, status}, socket) do
    dbg(status)

    socket =
      socket
      |> assign_link_status()
      |> assign_info()

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
        # connected?: false,
        # console_active?: NervesHubLink.console_active?(),
        console_active?: nerves_hub_link_console_active?()
      )
    else
      socket
    end
  catch
    _, _ ->
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
    <div :if={not @connected? or @status != :idle or @console_active? } class="fixed top-0 right-0 text-xs">
      <%= case @status do %>
        <% {:fwup_error, error} -> %>
          <div class="rounded-bl bg-red-600 text-white p-1 px-2">Error: <%= error %></div>
        <% {:updating, progress} -> %>
          <div class="w-full h-2"><div class="h-full bg-lime-500" style={"width: #{progress}%"}></div></div>

        <% :update_rescheduled -> %>
          <div class="rounded-bl bg-slate-200 text-slate-800 p-1 px-2">An update has been scheduled</div>
        <% _ -> %>

      <% end %>

      <div :if={@status != :blank and not @connected?}>
        <div class="rounded-bl bg-slate-200 text-slate-800 p-1 px-2">This device is not connected to the server.</div>
      </div>

      <div :if={@console_active?}>
        <div class="rounded-bl bg-slate-200 text-slate-800 p-4 px-8">A remote service console is active.</div>
      </div>

    </div>
    """
  end
end
