defmodule KioskCommonTest do
  use ExUnit.Case
  doctest KioskCommon

  test "greets the world" do
    assert KioskCommon.hello() == :world
  end
end
