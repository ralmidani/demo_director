defmodule DemoDirector.HEExTest do
  use ExUnit.Case, async: true

  doctest DemoDirector.HEEx

  describe "demo_id/1" do
    test "returns a keyword list with the data-demo-id attribute" do
      assert DemoDirector.HEEx.demo_id("save-prescription") ==
               [{:"data-demo-id", "save-prescription"}]
    end

    test "preserves the id verbatim — no escaping or transformation" do
      assert DemoDirector.HEEx.demo_id("complex_id-with.chars") ==
               [{:"data-demo-id", "complex_id-with.chars"}]
    end
  end
end
