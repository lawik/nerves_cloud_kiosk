defmodule Kiosk.Repo do
  use Ecto.Repo,
    otp_app: :kiosk,
    adapter: Ecto.Adapters.SQLite3
end
