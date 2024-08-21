defmodule Kiosk.Link do
  def get_config do
    Application.get_all_env(:nerves_hub_link)
    |> Keyword.take([:device_api_host, :shared_secret])
    |> Map.new()
  end

  def configured? do
    case attempt_start() do
      :ok -> true
      {:error, _} -> false
    end
  end

  def configure_link(key, secret, serial, api_host) do
    Application.put_env(:nerves_hub_link, :device_api_host, api_host)

    Application.put_env(:nerves_hub_link, :shared_secret,
      product_key: key,
      product_secret: secret,
      identifier: serial
    )
  end

  def attempt_start do
    case Application.ensure_all_started(:nerves_hub_link) do
      {:error, _details} ->
        {:error, :authentication_failed}

      {:ok, _apps} ->
        :ok
    end
  end
end
