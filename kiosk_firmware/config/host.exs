import Config

# Add configuration that is only needed when running on the host here.
config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       # The KV store on Nerves systems is typically read from UBoot-env, but
       # this allows us to use a pre-populated InMemory store when running on
       # host for development and testing.
       #
       # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
       # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata
       "a.nerves_fw_uuid" => "5cb84916-4c7c-55e9-2d20-e32ec6ba0b13",
       "a.nerves_fw_product" => System.fetch_env!("NERVES_PRODUCT_NAME"),
       "nerves_fw_active" => "a",
       "nerves_fw_devpath" => "_build/fwup.tmpfile",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0",
       "nerves_serial_number" => System.fetch_env!("NERVES_SERIAL_NUMBER")
     }}

config :nerves_time, :servers, []

config :kiosk_ui, KioskUiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  http: [port: 4002],
  secret_key_base: "HEY05EB1dFVSu6KykKHuS4rQPQzSHv4F7mGVB/gnDLrIu75wE/ytBXy2TaL3A6RA",
  live_view: [signing_salt: "AAAABjEyERMkxgDh"],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  render_errors: [view: KioskUiWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: KioskUi.PubSub,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:kiosk_ui, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:kiosk_ui, ~w(--watch)]}
  ],
  reloadable_apps: [:kiosk_ui],
  # Watch static and templates for browser reloading.
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/kiosk_ui_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix_live_reload, dirs: [Path.expand("../kiosk_ui")]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Include HEEx debug annotations as HTML comments in rendered markup
config :phoenix_live_view, :debug_heex_annotations, true

# Enable dev routes for dashboard and mailbox
config :kiosk_ui, dev_routes: true

config :nerves_hub_link,
  device_api_host: "devices.nervescloud.com",
  shared_secret: [
    product_key: System.get_env("NERVES_HUB_KEY"),
    product_secret: System.get_env("NERVES_HUB_SECRET"),
    identifier: System.fetch_env!("NERVES_SERIAL_NUMBER")
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
