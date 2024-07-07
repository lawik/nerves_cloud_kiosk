defmodule KioskCommon.MixProject do
  use Mix.Project

  def project do
    [
      app: :kiosk_common,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {KioskCommon.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_pubsub, "~> 2.1"},
      {:nerves_hub_link, "~> 2.4", runtime: false}
      # {:nerves_hub_link, github: "lawik/nerves_hub_link", branch: "host-dev-mode"},
    ]
  end
end
