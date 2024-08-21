defmodule KioskUiWeb.OnboardLive do
  use KioskUiWeb, :live_view

  def mount(_, _, socket) do
    if connected?(socket) do
      socket =
        socket
        |> assign_connection()

      check_connection()
      {:ok, socket}
    else
      {:ok, assign_connection(socket)}
    end
  end

  def render(assigns) do
    ~H"""


    <div :if={@network_up? and @link_set_up?} class="px-4 py-2 rounded-full bg-slate-300">The link to NervesHub has been set up.</div>
    <div :if={@network_up? and not @link_set_up?}>
        <h2 class="bold text-xl mb-8">Connect to NervesHub</h2>
        <p>Bring this device into your NervesHub account with a Shared Secret for the easiest onboarding.</p>
        <form id="nh_link" name="nh_link" phx-submit="submit_link" class="flex flex-wrap justify-center gap-4">
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">NervesHub instance</span>
              <input class="block w-full rounded-full bg-slate-200 border-0 text-center" type="text" id="nh_instance" name="nh_instance" value="devices.nervescloud.com" phx-update="ignore" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Serial number</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" id="nh_identifier" name="nh_identifer" value={System.unique_integer([:positive])} phx-update="ignore" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Product key</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" id="nh_key" name="nh_key" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Product secret</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" class="grow" id="nh_secret" name="nh_secret" />
            </label>
            <button>Connect</button>
        </form>
    </div>
    """
  end

  def handle_event(
        "submit_link",
        params,
        socket
      ) do
    KioskCommon.NervesHubManager.start(params)
    {:noreply, socket}
  end

  def handle_info(:check_connection, socket) do
    socket =
      socket
      |> assign_connection()

    check_connection()

    {:noreply, socket}
  end

  defp check_connection(), do: Process.send_after(self(), :check_connection, 500)

  defp assign_connection(socket),
    do:
      socket
      |> assign(network_up?: true, link_set_up?: KioskCommon.NervesHubManager.status().started?)
end
