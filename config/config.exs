# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

config :kiosk, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  kiosk: [
    args:
      ~w(./js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  kiosk: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ],
  keyboard: [
    args: ~w(
      --config=tailwind.config.js
      --input=js/keyboard/build/css/index.css
      --output=../priv/static/assets/keyboard.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1719505822"

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
