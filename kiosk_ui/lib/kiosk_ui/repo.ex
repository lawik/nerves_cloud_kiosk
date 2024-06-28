defmodule KioskUi.Repo do
  use Ecto.Repo,
    otp_app: :kiosk_ui,
    adapter: Ecto.Adapters.SQLite3
end
