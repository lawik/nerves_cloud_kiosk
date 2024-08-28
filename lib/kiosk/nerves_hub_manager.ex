defmodule Kiosk.NervesHubManager do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %{
      started?: false,
      starting?: false,
      pubsub: Keyword.fetch!(opts, :pubsub)
    }

    stored = get_prop_table()
    # This is disabled on host by default
    Application.put_env(:nerves_hub_link, :connect, true)
    set_application_env(stored)

    {:ok, state, {:continue, :start}}
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def start do
    GenServer.call(__MODULE__, :start)
  end

  def start(nh_map) do
    GenServer.call(__MODULE__, {:start, nh_map})
  end

  def remove_credentials do
    GenServer.call(__MODULE__, :remove_credentials)
  end

  def handle_continue(:start, state) do
    case Application.ensure_all_started(:nerves_hub_link) do
      {:ok, _apps} ->
        Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :started})
        {:noreply, %{state | started?: true, starting?: false}}

      {:error, {:nerves_hub_link, _}} ->
        Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :not_started})
        {:noreply, %{state | started?: false, starting?: false}}
    end
  end

  def handle_continue({:start, nh_creds}, state) do
    starting_config = Application.get_all_env(:nerves_hub_link)

    new = Enum.map(nh_creds, fn {key, value} -> {[key], value} end) |> Map.new()
    # Temporarily set the new config
    set_application_env(new)

    result =
      case Application.ensure_all_started(:nerves_hub_link) do
        {:ok, _apps} ->
          # Persist the new config
          write_prop_table(new)
          Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :started})
          {:noreply, %{state | started?: true, starting?: false}}

        {:error, {:nerves_hub_link, _}} ->
          Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :not_started})
          # Restore the old config
          Application.put_all_env(nerves_hub_link: starting_config)
          {:noreply, %{state | started?: false, starting?: false}}
      end
  end

  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:starting?, :started?]), state}
  end

  def handle_call(:start, _from, state) do
    if not state.starting? do
      Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :starting})
      {:reply, :ok, %{state | starting?: true}, {:continue, :start}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call({:start, nh_map}, _from, state) do
    if not state.starting? do
      Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :starting})
      {:reply, :ok, %{state | starting?: true}, {:continue, {:start, nh_map}}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:remove_credentials, _from, state) do
    starting_config = Application.get_all_env(:nerves_hub_link)
    config = Keyword.delete(starting_config, :shared_secret)
    Application.put_all_env(nerves_hub_link: config)
    PropertyTable.delete(Kiosk.NervesHub, "nh_instance")
    PropertyTable.delete(Kiosk.NervesHub, "nh_identifier")
    PropertyTable.delete(Kiosk.NervesHub, "nh_key")
    PropertyTable.delete(Kiosk.NervesHub, "nh_secret")
    Application.stop(:nerves_hub_link)
    Phoenix.PubSub.broadcast(state.pubsub, "nerves_hub_manager", {:link, :stopped})
    {:reply, :ok, %{state | started?: false, starting?: false}}
  end

  defp get_prop_table do
    PropertyTable.get_all(Kiosk.NervesHub) |> Map.new()
  end

  defp write_prop_table(new) do
    PropertyTable.put_many(Kiosk.NervesHub, Enum.to_list(new))
    PropertyTable.flush_to_disk(Kiosk.NervesHub)
  end

  @keys %{
    ["nh_instance"] => [:device_api_host],
    ["nh_key"] => [:shared_secret, :product_key],
    ["nh_secret"] => [:shared_secret, :product_secret],
    ["nh_identifer"] => [:shared_secret, :identifier]
  }

  defp set_application_env(new) do
    config = Application.get_all_env(:nerves_hub_link)

    config =
      @keys
      |> Enum.reduce(config, fn {key, config_path}, config ->
        case Map.get(new, key) do
          nil ->
            config

          value ->
            put_in(config, config_path, value)
        end
      end)

    Application.put_all_env(nerves_hub_link: config)

    IO.puts("Application config to connect with")
    Application.get_all_env(:nerves_hub_link) |> dbg()
  end
end
