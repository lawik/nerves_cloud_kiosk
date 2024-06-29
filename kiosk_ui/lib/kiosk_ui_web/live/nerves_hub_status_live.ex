defmodule KioskUiWeb.NervesHubStatusLive do
  @moduledoc """
  TODO: docs
  """
  use KioskUiWeb, :live_view

  alias Phoenix.LiveView.JS
  import KioskUiWeb.Gettext

  @doc """
  TODO: doc
  """
  def mount(_, _, socket) do
    socket =
      socket
      |> assign_info()

    refresh(socket)

    {:ok, socket}
  end

  defp handle_info(:update_status, socket) do
    socket = assign_info(socket)

    refresh(socket)
    {:noreply, socket}
  end

  defp assign_info(socket) do
    socket
    |> assign(
      status: NervesHubLink.status(),
      # status: {:fwup_error, "There was a problem updating this device."},
      # status: {:updating, 33},
      # status: :update_rescheduled,
      connected?: NervesHubLink.connected?(),
      # connected?: false,
      # console_active?: NervesHubLink.console_active?(),
      console_active?: true
    )
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
    <div :if={not @connected? or @status != :idle or @console_active? } class="fixed top-4 left-0 right-0 w-screen flex justify-center">
      <%= case @status do %>
        <% {:fwup_error, error} -> %>
          <div class="rounded-full bg-red-600 text-white p-4 px-8">Error: <%= error %></div>
        <% {:updating, progress} -> %>
          <div class="w-full h-2"><div class="h-full bg-lime-500" style={"width: #{progress}%"}></div></div>

        <% :update_rescheduled -> %>
          <div class="rounded-full bg-slate-300 p-4 px-8">An update has been scheduled</div>
        <% _ -> %>

      <% end %>

      <div :if={not @connected?}>
        <div class="rounded-full bg-slate-300 p-4 px-8">This device is not connected to the server.</div>
      </div>

      <div :if={@console_active?}>
        <div class="rounded-full bg-slate-300 p-4 px-8">A remote service console is active.</div>
      </div>

    </div>
    """
  end
end
