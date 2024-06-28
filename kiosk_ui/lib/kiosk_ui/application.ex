defmodule KioskUi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      KioskUiWeb.Telemetry,
      # TODO: Wire up something reasonable for Ecto and migrations
      #KioskUi.Repo,
      #{Ecto.Migrator,
      #  repos: Application.fetch_env!(:kiosk_ui, :ecto_repos),
      #  skip: skip_migrations?()},
      # TODO: Consider removing DNSCluster
      #{DNSCluster, query: Application.get_env(:kiosk_ui, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KioskUi.PubSub},
      # Start a worker by calling: KioskUi.Worker.start_link(arg)
      # {KioskUi.Worker, arg},
      # Start to serve requests, typically the last entry
      KioskUiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KioskUi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KioskUiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # defp skip_migrations?() do
  #   # By default, sqlite migrations are run when using a release
  #   System.get_env("RELEASE_NAME") != nil
  # end
end
