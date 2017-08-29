defmodule SamlyTest do
  use ExUnit.Case
  doctest Samly

  test "greets the world" do
    assert Samly.hello() == :world
  end
end
