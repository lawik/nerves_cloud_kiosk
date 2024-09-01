defmodule Kiosk.NetworkManager do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    state = %{
      wifi: Keyword.get(opts, :wifi, nil),
      wired: Keyword.get(opts, :wired, []),
      # Truncate AP name to 32 characters
      ap_name: Keyword.get(opts, :ap_name, Nerves.Runtime.serial_number()) |> String.slice(0..31),
      ssid: nil,
      psk: nil
    }

    try do
      schedule_self_check()

      Enum.each(state.wired, fn interface ->
        VintageNet.subscribe(["interface", interface, :_])
      end)

      if state.wifi do
        VintageNet.subscribe(["interface", state.wifi, :_])
        {:ok, state, {:continue, :setup}}
      else
        {:ok, state}
      end
    rescue
      _ ->
        # Probably not on-device, VintageNet is missing
        {:ok, state}
    end
  end

  def has_internet? do
    GenServer.call(__MODULE__, :has_internet?)
  end

  def wifi_status do
    GenServer.call(__MODULE__, :wifi_status)
  end

  def get_ips do
    GenServer.call(__MODULE__, :get_ips)
  end

  def scan do
    GenServer.cast(__MODULE__, :scan)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Kiosk.PubSub, "network-manager")
  end

  def connect(ssid, psk) do
    GenServer.cast(__MODULE__, {:connect, ssid, psk})
  end

  def disconnect do
    GenServer.cast(__MODULE__, :disconnect)
  end

  # Figure out initial state as best we can
  @impl GenServer
  def handle_continue(:setup, state) do
    case get_status(state.wifi) do
      %{
        "config" => %{type: VintageNetWiFi, vintage_net_wifi: %{networks: [%{mode: :ap}]}},
        "state" => :configured,
        "connection" => _conn
      } ->
        # Connection is in AP mode, do nothing
        :ok

      %{"config" => %{type: VintageNetWiFi}, "state" => :configured, "connection" => conn}
      when conn in [:lan, :internet] ->
        # Connection is OK, do nothing
        :ok

      %{
        "config" => %{type: VintageNetWiFi},
        "state" => :configured,
        "connection" => :disconnected
      } ->
        # Probably disconnected or not connected yet, chill, but check again later
        Process.send_after(self(), :expect_connection, 10_000)

      %{"config" => %{type: VintageNet.Technology.Null}} ->
        # Deconfigured, go to AP mode
        configure_ap_mode(state.wifi, state.ap_name)
        :ok

      net_status ->
        Logger.debug("Net status: #{inspect(net_status)}")
        :ok
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:check, state) do
    schedule_self_check()
    # Run setup to check wifi status
    {:noreply, state, {:continue, :setup}}
  end

  def handle_info(:expect_connection, state) do
    state =
      case get_status(state.wifi) do
        %{"config" => %{type: VintageNetWiFi}, "state" => :configured, "connection" => conn}
        when conn in [:lan, :internet] ->
          Logger.info("Connected, as expected.")
          # Connection is OK, do nothing
          state

        status ->
          Logger.info("Connection seems to have failed, switching to AP mode")
          Logger.info("Status: #{inspect(status)}")

          if state.ssid do
            Phoenix.PubSub.broadcast(
              Kiosk.PubSub,
              "network-manager",
              {:connection_failed, state.ssid}
            )
          end

          configure_ap_mode(state.wifi, state.ap_name)
          %{state | ssid: nil, psk: nil}
      end

    {:noreply, state}
  end

  def handle_info({VintageNet, prop, pre, post, meta}, state) do
    handle_change(prop, pre, post, meta, state)
  end

  defp handle_change(
         ["interface", wifi, "state"],
         :configuring,
         :configured,
         _metadata,
         %{wifi: wifi} = state
       ) do
    Logger.info(
      "NetworkManager: interface #{wifi} configured, 10 sec until we expect to be connected..."
    )

    Process.send_after(self(), :expect_connection, 10_000)
    {:noreply, state}
  end

  defp handle_change(
         ["interface", wifi, "wifi", "access_points"],
         _,
         aps,
         _metadata,
         %{wifi: wifi} = state
       ) do
    Logger.info("#{wifi}: received APs: #{Enum.map(aps, & &1.ssid)}")
    Phoenix.PubSub.broadcast(Kiosk.PubSub, "network-manager", {:access_points, aps})
    {:noreply, state}
  end

  defp handle_change(
         ["interface", wifi, "wifi", "clients"],
         [],
         clients,
         _metadata,
         %{wifi: wifi} = state
       ) do
    Logger.info("#{wifi}: clients connected to AP: #{inspect(clients)}")
    {:noreply, state}
  end

  defp handle_change(property, old_value, new_value, metadata, state) do
    Logger.info(
      "VintageNet change: #{inspect(property)} from #{inspect(old_value)} to #{inspect(new_value)} .. #{inspect(metadata)}"
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:has_internet?, _from, state) do
    internet? =
      [state.wifi | state.wired]
      |> Enum.reject(&is_nil/1)
      |> Enum.any?(&interface_has_internet?/1)

    {:reply, internet?, state}
  end

  @impl GenServer
  def handle_call(:wifi_status, _from, state) do
    status =
      if is_nil(state.wifi) do
        %{exists?: false, ap_mode?: false, connected?: false, name: ""}
      else
        case get_status(state.wifi) do
          %{
            "config" => %{type: VintageNetWiFi, vintage_net_wifi: %{networks: [%{mode: :ap}]}},
            "state" => :configured,
            "connection" => _conn
          } ->
            %{exists?: true, ap_mode?: true, connected?: false, name: ""}

          %{"config" => %{type: VintageNetWiFi}, "state" => :configured, "connection" => conn}
          when conn in [:lan, :internet] ->
            %{exists?: true, ap_mode?: false, connected?: true, name: state.ssid}

          _ ->
            %{exists?: true, ap_mode?: false, connected?: false, name: ""}
        end
      end

    {:reply, status, state}
  end

  def handle_call(:get_ips, _from, state) do
    ips =
      PropertyTable.match(VintageNet, ["interface", :_, "addresses"])
      |> Enum.flat_map(fn {_key, addresses} ->
        addresses
        |> Enum.filter(fn %{family: fam} ->
          fam == :inet
        end)
        |> Enum.map(fn {a, b, c, d} ->
          "#{a}.#{b}.#{c}.#{d}"
        end)
      end)

    {:reply, ips, state}
  rescue
    _ ->
      # Probably not on-device
      {:reply, ["127.0.0.1"], state}
  end

  @impl GenServer
  def handle_cast(:scan, state) do
    try do
      VintageNet.scan(state.wifi)
    rescue
      _ ->
        # No wifi interface or not on-device
        :ok
    end

    {:noreply, state}
  end

  def handle_cast({:connect, ssid, psk}, state) do
    if state.wifi do
      attemp_wifi_connection(state.wifi, ssid, psk)
      {:noreply, %{state | ssid: ssid, psk: psk}}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:disconnect, state) do
    if state.wifi do
      configure_ap_mode(state.wifi, state.ap_name)
      {:noreply, %{state | ssid: nil, psk: nil}}
    else
      {:noreply, state}
    end
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
    })
  end

  defp interface_has_internet?(interface) do
    case get_status(interface) do
      %{"state" => :configured, "connection" => :internet} ->
        true

      _ ->
        false
    end
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

  defp schedule_self_check do
    Process.send_after(self(), :check, 10_000)
  end
end
