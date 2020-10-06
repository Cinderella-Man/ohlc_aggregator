defmodule TempTest do
  use ExUnit.Case
  doctest Temp

  test "greets the world" do
    assert Temp.hello() == :world
  end
end
