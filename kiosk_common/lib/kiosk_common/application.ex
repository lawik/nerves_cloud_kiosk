defmodule KioskCommon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @persist_path (case Mix.target() do
                   :host -> "./_build/nerves_hub_manager"
                   _target -> "/data/nerves_hub_manager"
                 end)

  @impl true
  def start(_type, _args) do
    File.mkdir_p!(@persist_path)

    children = [
      {PropertyTable, name: KioskCommon.NervesHub, persist_data_path: @persist_path},
      {KioskCommon.NervesHubManager, pubsub: KioskUi.PubSub}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KioskCommon.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
