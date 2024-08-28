defmodule Kiosk.WifiManager do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    state = %{
      interface: Keyword.fetch!(opts, :interface),
      ap_name: Keyword.get(opts, :ap_name, Nerves.Runtime.serial_number()),
      ssid: nil,
      psk: nil
    }
    try do
      VintageNet.subscribe(["interface", state.interface, :_])
      {:ok, state, {:continue, :setup}}
    rescue 
      _ ->
        # Probably not on-device, VintageNet is missing
        {:ok, state}
    end
  end

  def connected? do
    GenServer.call(__MODULE__, :connected?)
  end

  def scan do
    Logger.info("Scan requested...")
    GenServer.cast(__MODULE__, :scan)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Kiosk.PubSub, "wifi")
  end

  def connect(ssid, psk) do
    GenServer.cast(__MODULE__, {:connect, ssid, psk})
  end

  # Figure out initial state as best we can
  @impl GenServer
  def handle_continue(:setup, state) do
    case get_status(state.interface) do
      %{"config" => %{type: VintageNetWiFi, vintage_net_wifi: %{networks: [%{mode: :ap}]}}, "state" => :configured, "connection" => conn} ->
        # Connection is in AP mode, do nothing
        :ok
      %{"config" => %{type: VintageNetWiFi}, "state" => :configured, "connection" => conn} when conn in [:lan, :internet] ->
        # Connection is OK, do nothing
        :ok
      %{"config" => %{type: VintageNetWiFi}, "state" => :configured, "connection" => :disconnected} ->
        # Probably disconnected or not connected yet, chill, but check again later
        Process.send_after(self(), :expect_connection, 10_000)
      %{"config" => %{type: VintageNet.Technology.Null}} ->
        # Deconfigured, go to AP mode
        configure_ap_mode(state.interface, state.ap_name)
      net_status ->
        Logger.debug("Net status: #{inspect(net_status)}")
        :ok
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({VintageNet, ["interface", _, "state"], :configuring, :configured, _metadata}, state) do
    Logger.info("WifiManager: interface configured, 10 sec until we expect to be connected...")
    Process.send_after(self(), :expect_connection, 10_000)
    {:noreply, state}
  end

  def handle_info({VintageNet, ["interface", _, "wifi", "access_points"], _, aps, _metadata}, state) do
    Logger.info("Received APs: #{Enum.map(aps, & &1.ssid)}")
    Phoenix.PubSub.broadcast(Kiosk.PubSub, "wifi", {:access_points, aps})
    {:noreply, state}
  end

  def handle_info({VintageNet, ["interface", _, "wifi", "clients"], [], clients, _metadata}, state) do
    Logger.info("Clients connected to AP: #{inspect(clients)}")
    {:noreply, state}
  end

  def handle_info({VintageNet, property, old_value, new_value, metadata}, state) do
    Logger.info("VintageNet change: #{inspect(property)} from #{inspect(old_value)} to #{inspect(new_value)} .. #{inspect(metadata)}")
    {:noreply, state}
  end

  def handle_info(:expect_connection, state) do
    state =
      case get_status(state.interface) do
        %{"config" => %{type: VintageNetWiFi}, "state" => :configured, "connection" => conn} when conn in [:lan, :internet] ->
          Logger.info("Connected, as expected.")
          # Connection is OK, do nothing
          state
        status ->
          Logger.info("Connection seems to have failed, switchin to AP mode")
          Logger.info("Status: #{inspect(status)}")
          if state.ssid do
            Phoenix.PubSub.broadcast(Kiosk.PubSub, "wifi", {:connection_failed, state.ssid})
          end
          configure_ap_mode(state.interface, state.ap_name)
          %{state | ssid: nil, psk: nil}
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:connected?, _from, state) do
    case get_status(state.interface) do
      %{"config" => %{type: VintageNetWiFi, vintage_net_wifi: %{networks: [%{mode: mode}]}}, "state" => :configured, "connection" => conn} when conn in [:lan, :internet] and mode != :ap ->
        # Connection is OK, do nothing
        {:reply, true, state}
      _ ->
        {:reply, false, state}
    end
  end

  @impl GenServer
  def handle_cast(:scan, state) do
    try do
      VintageNet.scan(state.interface)
    rescue
      _ ->
        # Probably not on-device
        :ok
    end
    {:noreply, state}
  end

  def handle_cast({:connect, ssid, psk}, state) do
    attemp_wifi_connection(state.interface, ssid, psk)
    {:noreply, %{state | ssid: ssid, psk: psk}}
  end

  def configure_ap_mode(interface, name) do
    Logger.info("Reconfiguring into AP mode: #{interface} #{name}")
    VintageNet.configure(interface, %{
      type: VintageNetWiFi,
      vintage_net_wifi: %{
        networks: [
          %{
            mode: :ap,
            ssid: name,
            key_mgmt: :none
          }
        ]
      },
      ipv4: %{
        method: :static,
        address: "192.168.24.1",
        netmask: "255.255.255.0"
      },
      dhcpd: %{
        start: "192.168.24.2",
        end: "192.168.24.10",
        options: %{
          dns: ["1.1.1.1", "1.0.0.1"],
          subnet: "255.255.255.0",
          router: ["192.168.24.1"]
        }
      }
    })
  end

  def attemp_wifi_connection(interface, ssid, psk) do
    VintageNet.configure(interface, %{
      type: VintageNetWiFi,
      ipv4: %{method: :dhcp},
      vintage_net_wifi: %{
        networks: [
          %{
            key_mgmt: :wpa_psk,
            ssid: ssid,
            psk: psk
          }
        ]
      }
    }
    )
  end

  defp get_status(interface) do
    try do
      for {[_, _, field], value} <- VintageNet.match(["interface", interface, :_]), into: %{} do
        {field, value}
      end
    rescue
      _ ->
        # Probably not on-device
        %{}
    end
  end
end