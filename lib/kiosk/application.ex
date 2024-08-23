defmodule Kiosk.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kiosk.Supervisor]

    children =
      [
        {Phoenix.PubSub, name: Kiosk.PubSub},
        {PropertyTable, name: Kiosk.NervesHub, persist_data_path: @persist_path},
        {Kiosk.NervesHubManager, pubsub: Kiosk.PubSub},
        {Kiosk.WifiManager, interface: "wlan0", ap_name: "Setup #{Nerves.Runtime.serial_number()}"},
        KioskWeb.Telemetry,
        # TODO: Wire up something reasonable for Ecto and migrations
        # Kiosk.Repo,
        # {Ecto.Migrator,
        #  repos: Application.fetch_env!(:kiosk, :ecto_repos),
        #  skip: skip_migrations?()},
        # TODO: Consider removing DNSCluster
        # {DNSCluster, query: Application.get_env(:kiosk, :dns_cluster_query) || :ignore},
        # Start a worker by calling: Kiosk.Worker.start_link(arg)
        # {Kiosk.Worker, arg},
        # Start to serve requests, typically the last entry
        KioskWeb.Endpoint
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  def children(:frio_rpi4) do
    config = Application.get_env(:kiosk, KioskWeb.Endpoint)
    host = config[:url][:host]
    port = config[:http][:port]
    [
      {Kiosk, dir: "/data", starting_page: "http://#{host}:#{port}"}
    ]
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Kiosk.Worker.start_link(arg)
      # {Kiosk.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Kiosk.Worker.start_link(arg)
      # {Kiosk.Worker, arg},
    ]
  end

  @impl true
  def config_change(changed, _new, removed) do
    KioskWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def target() do
    Application.get_env(:kiosk, :target)
  end
end
