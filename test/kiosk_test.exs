defmodule KioskTest do
  use ExUnit.Case
  doctest Kiosk

  test "greets the world" do
    assert Kiosk.hello() == :world
  end
end
