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
    config = Application.get_env(:kiosk_ui, KioskUiWeb.Endpoint)
    host = config[:url][:host]
    port = config[:http][:port]

    children =
      [
        {Kiosk, dir: "/data", starting_page: "http://#{host}:#{port}"},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
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

  def target() do
    Application.get_env(:kiosk, :target)
  end
end
