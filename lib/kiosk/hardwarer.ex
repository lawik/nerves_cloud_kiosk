defmodule Kiosk.Hardwarer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl GenServer
  def init(_) do
    # Phoenix.PubSub.subscribe(Kiosk.PubSub, "amplitude")
    Phoenix.PubSub.subscribe(Kiosk.PubSub, "speaking")
    state = %{timer: nil}
    {:ok, state}
  end

  @impl GenServer
  def handle_info({:speaking, :start, _prob}, state) do
    # File.write!("/sys/class/backlight/lcd_backlight/brightness", "5\n")

    # timer =
    #   if state.timer do
    #     state.timer
    #   else
    #     Process.send_after(self(), :dim, 1500)
    #   end
    timer = nil

    {:noreply, %{state | timer: timer}}
  end

  def handle_info({:speaking, :stop, _prob}, state) do
    # File.write!("/sys/class/backlight/lcd_backlight/brightness", "1\n")
    {:noreply, state}
  end

  def handle_info(:dim, state) do
    # {level, _} = File.read!("/sys/class/backlight/lcd_backlight/brightness") |> Integer.parse()

    timer = nil
    # timer =
    #   if level > 0 do
    #     File.write!("/sys/class/backlight/lcd_backlight/brightness", "#{level - 1}\n")
    #     Process.send_after(self(), :dim, 1500)
    #   else
    #     nil
    #   end

    {:noreply, %{state | timer: timer}}
  end
end
