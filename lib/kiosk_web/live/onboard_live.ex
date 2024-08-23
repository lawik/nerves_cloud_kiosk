defmodule KioskWeb.OnboardLive do
  use KioskWeb, :live_view

  alias Kiosk.WifiManager

  require Logger

  def mount(_, _, socket) do
    if connected?(socket) do
      WifiManager.subscribe()
      socket =
        socket
        |> assign(access_points: [], selected_ssid: nil, connecting_ssid: nil)
        |> assign_connection()

      check_connection()
      {:ok, socket}
    else
      socket =
        socket
        |> assign(access_points: [], selected_ssid: nil, connecting_ssid: nil)
        |> assign_connection()
      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""

    <div :if={!@network_up?}>
        <h2 :if={@access_points != []} class="bold text-xl mb-8">Connect to Wi-Fi</h2>
        <p :if={@access_points == []}>Scanning Wi-Fi...</p>
        <div :for={ap <- @access_points}>
          <button phx-value-ssid={ap.ssid} phx-click="select-ap">
            <h3><%= ap.ssid %></h3>
            <div>Signal: <%= ap.signal_percent %>%</div>
          </button>
          <form :if={ap.ssid == @selected_ssid} id="wifi" name="wifi" phx-submit="connect-wifi" class="flex flex-wrap justify-center gap-4">
              <label class="block w-full flex flex-wrap justify-center">
                <span class="block w-full text-center">Passkey</span>
                <input class="block w-full rounded-full bg-slate-200 border-0 text-center" type="text" id="psk" name="psk" value="" phx-update="ignore" />
              </label>
              <button>Connect</button>
          </form>
        </div>
    </div>

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
    Kiosk.NervesHubManager.start(params)
    {:noreply, socket}
  end

  def handle_event("select-ap", %{"ssid" => ssid}, socket) do
    {:noreply, assign(socket, selected_ssid: ssid)}
  end

  def handle_event("connect-wifi", %{"psk" => psk}, socket) do
    WifiManager.connect(socket.assigns.selected_ssid, psk)
    {:noreply, assign(socket, connecting_ssid: socket.assigns.selected_ssid, selected_ssid: nil)}
  end

  def handle_info(:check_connection, socket) do
    socket =
      socket
      |> assign_connection()

    check_connection()

    {:noreply, socket}
  end

  def handle_info({:access_points, aps}, socket) do
    Logger.info("Received APs: #{inspect(aps)}")
    {:noreply, assign(socket, access_points: aps)}
  end

  def handle_info({:connection_failed, ssid}, socket) do
    Logger.info("Connection failed: #{ssid}")
    {:noreply, assign(socket, connecting_ssid: nil)}
  end

  defp check_connection(), do: Process.send_after(self(), :check_connection, 500)

  defp assign_connection(socket) do
    connected? = WifiManager.connected?()
    if not connected? do
      WifiManager.scan()
    end

    socket
    |> assign(network_up?: connected?, link_set_up?: Kiosk.NervesHubManager.status().started?)
  end
end
