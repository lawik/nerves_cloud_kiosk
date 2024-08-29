defmodule KioskWeb.OnboardLive do
  use KioskWeb, :live_view

  alias Kiosk.NetworkManager

  require Logger

  def mount(_, _, socket) do
    Logger.info("mount")
    if connected?(socket) do
      Logger.info("Connecting LiveView...")
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
      Logger.info("Connected LiveView: OK")
      {:ok, socket}
    else
      Logger.info("Dead rendering...")
      socket =
        socket
        |> assign(access_points: [], selected_ssid: nil, connecting_ssid: nil, hostname: nil)
        |> assign_connection()

      Logger.info("Dead render: OK")
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
    Logger.info("render")
    ~H"""
    <div :if={@hostname} class="absolute bottom-2 right-2">
    Device: <%= @hostname %>.local
    </div>

    <div :if={!@wifi.exists?} id="wifi-control">
        <div :if={@access_points == []}>
          <h2>Wi-Fi</h2>
          <p>Scanning Wi-Fi...</p>
        </div>
        <h2 :if={@access_points != []} class="bold text-xl mb-8">Connect to Wi-Fi</h2>
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

    <div :if={@link_set_up?} class="px-4 py-2 rounded-full bg-slate-300">The link to NervesHub has been set up.</div>
    <div :if={not @link_set_up?}>
        <h2 class="bold text-xl mb-8">Connect to NervesHub</h2>
        <p>Bring this device into your NervesHub account with a Shared Secret for the easiest onboarding.</p>
        <form id="nh_link" name="nh_link" phx-submit="submit_link" class="flex flex-wrap justify-center gap-4">
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">NervesHub instance</span>
              <input class="block w-full rounded-full bg-slate-200 border-0 text-center" type="text" id="nh_instance" name="nh_instance" value="devices.nervescloud.com" phx-update="ignore" />
            </label>
            <label class="block w-full flex flex-wrap justify-center">
              <span class="block w-full text-center">Serial number</span>
              <input class="block w-full rounded-full bg-slate-200 border-0  text-center" type="text" id="nh_identifier" name="nh_identifer" value={Nerves.Runtime.serial_number()} phx-update="ignore" />
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
    Logger.info("event submit_link")
    Kiosk.NervesHubManager.start(params)
    {:noreply, socket}
  end

  def handle_event("select-ap", %{"ssid" => ssid}, socket) do
    Logger.info("event select-ap")
    {:noreply, assign(socket, selected_ssid: ssid)}
  end

  def handle_event("connect-wifi", %{"psk" => psk}, socket) do
    Logger.info("event connect-wifi")
    NetworkManager.connect(socket.assigns.selected_ssid, psk)
    {:noreply, assign(socket, connecting_ssid: socket.assigns.selected_ssid, selected_ssid: nil)}
  end

  def handle_info(:check_connection, socket) do
    Logger.info("info check_connection")
    socket =
      socket
      |> assign_connection()

    #check_connection()

    {:noreply, socket}
  end

  def handle_info(:scan_wifi, socket) do
    Logger.info("info scan_wifi")
    if socket.assigns.wifi.exists? and not socket.assigns.wifi.connected? do
      NetworkManager.scan()
    end

    #scan_wifi()
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

  defp check_connection(), do: Process.send_after(self(), :check_connection, 5000)
  defp scan_wifi(), do: Process.send_after(self(), :scan_wifi, 10_000)

  defp assign_connection(socket) do
    Logger.info("assign connection")
    socket
    |> assign(
      wifi: NetworkManager.wifi_status(),
      internet?: NetworkManager.has_internet?(),
      link_set_up?: Kiosk.NervesHubManager.status().started?
    )
  end
end
