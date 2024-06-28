defmodule KioskUiWeb.OnboardLive do
    use KioskUiWeb, :live_view
    def mount(_, _, socket) do
        socket =
            socket
            |> assign_connection()

        check_connection()
        {:ok, socket}
    end

    def render(assigns) do
        ~H"""
        <h2 class="bold text-xl mb-8">NervesHubLink status</h2>

        <div :if={@connected?} class="px-4 py-2 rounded-full bg-slate-300">Connected</div>
        <div :if={!@connected?} class="px-4 py-2 rounded-full bg-slate-300">Not connected</div>
        """
    end

    def handle_info(:check_connection, socket) do
        socket =
            socket
            |> assign_connection()

        check_connection()

        {:noreply, socket}
    end

    defp check_connection(), do: Process.send_after(self(), :check_connection, 500)

    defp assign_connection(socket), do:
        socket
        |> assign(connected?: NervesHubLink.connected?())
end