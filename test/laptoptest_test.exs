defmodule LaptoptestTest do
  use ExUnit.Case
  doctest Laptoptest

  test "greets the world" do
    assert Laptoptest.hello() == :world
  end
end
