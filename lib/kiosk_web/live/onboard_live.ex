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
          hostname: hostname(),
          ips: []
        )
        |> assign_connection()

      check_connection()
      scan_wifi()

      Logger.info("Mount")

      {:ok, socket}
    else
      socket =
        socket
        |> assign(
          access_points: [],
          selected_ssid: nil,
          connecting_ssid: nil,
          hostname: nil,
          ips: []
        )
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

  def interfaces(assigns) do
    ~H"""
    <div :if={not @status.wifi.connected?} class="p-2 px-4 rounded-lg bg-slate-200">
      <label :for={%{name: iface, status: status} <- @status.wired} id={"interface-" <> iface}
        class="block flex basis-1/2 gap-4 my-2">
        <span class="content-center"><%= iface %></span>
        <span class="flex-grow rounded-md bg-slate-300 p-2 px-4"><%= status %></span>
      </label>
      <div :if={@status.wifi.exists?} class="">
        <label id="wifi-block" :if={@status.wifi.exists?} class="block flex basis-1/2 gap-4 my-2">
          <span class="content-start">Wi-Fi</span>
          <span class="flex-grow">
            <p :if={@access_points == []}>No networks found</p>
            <button :for={ap <- @access_points} id={"ap-" <> ap.ssid} class="block w-full text-left bg-slate-500 text-sm text-white rounded-lg p-2 px-4 mb-1" phx-value-ssid={ap.ssid} phx-click="select-ap"><%= ap.ssid %> (<%= ap.signal_percent %>%)</button>
          </span>
        </label>
        <form phx-submit="connect-wifi" class="block">
          <label class="block flex basis-1/2 gap-4 my-2" :if={not is_nil(@selected_ssid)}>
            <span class="content-center">Passkey </span>
            <input class="border-0 rounded-md flex-grow bg-white" type="text" id="psk" name="psk" phx-update="ignore" />
          </label>
          <div id="wifi-connect-button" :if={@selected_ssid} class="mt-4 flex justify-end">
            <button class="rounded-md bg-lime-600 text-white px-4 py-2 text-right">Connect</button>
          </div>
        </form>
      </div>
    </div>
    <form :if={@status.wifi.connected?} phx-submit="disconnect-wifi" class="rounded p-2 ">
      <label :for={%{name: iface, status: status} <- @status.wired} id={"interface-" <> iface} class="block mb-2"><%= iface %>: <%= status %></label>
      <label class="block mb-2">Wi-fi: <%= @status.wifi.name %></label>
      <div id="wifi-disconnect-button" :if={@status.wifi.connected?} class="mt-4 flex justify-end">
        <button class="rounded-md bg-lime-600 text-white px-4 py-2 basis-1/2">Disconnect</button>
      </div>
    </form>
    """
  end

  def render(assigns) do
    ~H"""
    <!--<h1 class="text-6xl text-center uppercase mb-12">Welcome</h1>-->

    <!-- <pre><%= inspect(assigns, pretty: true) %></pre> -->
    <div id="internet-status">
      <div class="flex gap-4">
      <%= if @status.internet? do %>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6 min-w-8 text-lime-600">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <div class="flex-grow">
          <div class="">
            <h2 class="text-lg font-bold text-lime-600">Connect to the Internet</h2>
          </div>
          <.interfaces id="aps" status={@status} selected_ssid={@selected_ssid} access_points={@access_points} />
        </div>
      <% else %>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6 min-w-8">
          <path stroke-linecap="round" stroke-linejoin="round" d="m9.75 9.75 4.5 4.5m0-4.5-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <div class="flex-grow">
          <div class="">
            <h2 class="text-lg font-bold mb-4">Connect to the Internet</h2>
          </div>
          <.interfaces id="aps" status={@status} selected_ssid={@selected_ssid} access_points={@access_points} />
        </div>
      <% end %>
      </div>
    </div>

    <div id="link-status" class="mt-8">
      <%= if @link_set_up? do %>
      <div id="link-ready" class="flex gap-4">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6 min-w-8 text-lime-600">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <div class="flex-grow">
          <div class="">
            <h2 class="text-lg font-bold text-lime-600">NervesHub link ready</h2>
          </div>
        </div>
      </div>

      <% else %>
      <div id="link-configure-form" class="flex mt-8 gap-4">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6 min-w-8">
          <path stroke-linecap="round" stroke-linejoin="round" d="m9.75 9.75 4.5 4.5m0-4.5-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <div class="flex-grow">
          <div class="">
            <h2 class="text-lg font-bold mb-4">Configure your NervesHub link</h2>

            <p class="my-4">Bring this device into your NervesHub account with a Shared Secret for the easiest onboarding.</p>
            <form id="nh_link" name="nh_link" phx-submit="submit_link" class="bg-slate-200 rounded-lg p-2 px-4">
                <label class="block flex basis-1/2 gap-4 my-2">
                  <span class="content-center">NervesHub instance</span>
                  <input class="border-0 rounded-md flex-grow bg-white" type="text" id="nh_instance" name="nh_instance" value="devices.nervescloud.com" phx-update="ignore" />
                </label>
                <label class="block flex basis-1/2 gap-4 my-2">
                  <span class="content-center">Serial number</span>
                  <input class="border-0 rounded-md flex-grow bg-white" type="text" id="nh_identifier" name="nh_identifer" value="" phx-update="ignore" />
                </label>
                <label class="block flex basis-1/2 gap-4 my-2">
                  <span class="content-center">Product key</span>
                  <input class="border-0 rounded-md flex-grow bg-white" type="text" id="nh_key" name="nh_key" phx-update="ignore" />
                </label>
                <label class="block flex basis-1/2 gap-4 my-2">
                  <span class="content-center">Product secret</span>
                  <input class="border-0 rounded-md flex-grow bg-white" type="text" class="grow" id="nh_secret" name="nh_secret" phx-update="ignore" />
                </label>
                <div id="nerves-hub-connect-button" class="mt-4 flex justify-end">
                  <button class="rounded-md bg-lime-600 text-white px-4 py-2 text-right">Connect</button>
              </div>
            </form>
          </div>
        </div>
      </div>
      <% end %>
    </div>

    <div id="hostname-container" :if={@hostname} class="fixed bottom-2 left-2">
    Device: <%= @hostname %>.local<br>
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
    ssid =
      case ssid do
        "--unset--" -> nil
        ssid -> ssid
      end

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
    if socket.assigns.status.wifi.exists? and not socket.assigns.status.wifi.connected? do
      NetworkManager.scan()
    end

    scan_wifi()
    {:noreply, socket}
  end

  def handle_info(:change, socket) do
    socket =
      socket
      |> assign_connection()

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
      status: NetworkManager.status(),
      # wifi: %{exists?: true, connected?: true, name: "My network", ap_mode?: false},
      # internet?: true,
      ips: NetworkManager.get_ips(),
      link_set_up?: Kiosk.NervesHubManager.status().started?
    )
  end
end
