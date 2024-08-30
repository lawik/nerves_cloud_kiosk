defmodule KioskWeb.OnboardLive do
  use KioskWeb, :live_view

  alias Kiosk.NetworkManager

  require Logger

  def mount(_, _, socket) do
    if connected?(socket) do
      NetworkManager.subscribe()

      socket =
        socket
        |> assign(
          access_points: [],
          selected_ssid: nil,
          connecting_ssid: nil,
          hostname: hostname()
        )
        |> assign_connection()

      check_connection()
      scan_wifi()

      {:ok, socket}
    else
      socket =
        socket
        |> assign(access_points: [], selected_ssid: nil, connecting_ssid: nil, hostname: nil)
        |> assign_connection()

      {:ok, socket}
    end
  end

  defp hostname do
    case :inet.gethostname() do
      {:ok, hostname_charlist} -> to_string(hostname_charlist)
      _ -> nil
    end
  end

  def render(assigns) do
    ~H"""
    <div id="hostname-container" :if={@hostname} class="absolute bottom-2 right-2">
    Device: <%= @hostname %>.local
    </div>

    <div id="wifi-control" :if={@wifi.exists?}>
        <div id="wifi-aps" :if={@access_points == []}>
          <h2>Wi-Fi</h2>
          <p>Scanning Wi-Fi...</p>
        </div>
        <div id="with-aps" :if={not @wifi.connected? and @access_points != []}>
          <h2 class="bold text-xl mb-8">Connect to Wi-Fi</h2>
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
        <div id="wifi-connected" :if={@wifi.connected?}>
          <h2>On network <%= @wifi.name %></h2>
          <form id="wifi-dc" name="wifi-dc" phx-submit="disconnect-wifi" class="">
            <button>Disconnect</button>
          </form>
        </div>
    </div>

    <div id="nh-link-ready" :if={@link_set_up?} class="px-4 py-2 rounded-full bg-slate-300">The link to NervesHub has been set up.</div>
    <div id="nh-form-container" :if={not @link_set_up?}>
        <h2 class="bold text-xl mb-8">Connect to NervesHub</h2>
        <p>Bring this device into your NervesHub account with a Shared Secret for the easiest onboarding.</p>
        <form id="nh_link" name="nh_link" phx-submit="submit_link" class="flex flex-wrap justify-center gap-4">
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">NervesHub instance</span>
              <input class="block w-full rounded-full bg-slate-200 border-0 text-center" type="text" id="nh_instance" name="nh_instance" value="devices.nervescloud.com" phx-update="ignore" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Serial number</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" id="nh_identifier" name="nh_identifer" value="" phx-update="ignore" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Product key</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" id="nh_key" name="nh_key" phx-update="ignore" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Product secret</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" class="grow" id="nh_secret" name="nh_secret" phx-update="ignore" />
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
    NetworkManager.connect(socket.assigns.selected_ssid, psk)
    {:noreply, assign(socket, connecting_ssid: socket.assigns.selected_ssid, selected_ssid: nil)}
  end

  def handle_event("disconnect-wifi", socket) do
    NetworkManager.disconnect()
    {:noreply, assign(socket, connecting_ssid: nil, selected_ssid: nil)}
  end

  def handle_info(:check_connection, socket) do
    socket =
      socket
      |> assign_connection()

    check_connection()

    {:noreply, socket}
  end

  def handle_info(:scan_wifi, socket) do
    if socket.assigns.wifi.exists? and not socket.assigns.wifi.connected? do
      NetworkManager.scan()
    end

    scan_wifi()
    {:noreply, socket}
  end

  def handle_info({:access_points, aps}, socket) do
    {:noreply, assign(socket, access_points: aps)}
  end

  def handle_info({:connection_failed, _ssid}, socket) do
    {:noreply, assign(socket, connecting_ssid: nil)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp check_connection() do
    Process.send_after(self(), :check_connection, 5000)
  end

  defp scan_wifi() do
    Process.send_after(self(), :scan_wifi, 10_000)
  end

  defp assign_connection(socket) do
    socket
    |> assign(
      wifi: NetworkManager.wifi_status(),
      internet?: NetworkManager.has_internet?(),
      link_set_up?: Kiosk.NervesHubManager.status().started?
    )
  end
end
