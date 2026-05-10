defmodule DemoDirectorTest do
  use ExUnit.Case, async: true

  doctest DemoDirector

  describe "subtitle/1" do
    test "emits JS that calls the runtime helper with the text" do
      assert DemoDirector.subtitle("Hello") ==
               ~s|window.DemoDirector.subtitle("Hello");|
    end

    test "escapes embedded quotes" do
      assert DemoDirector.subtitle(~s|she said "hi"|) ==
               ~s|window.DemoDirector.subtitle("she said \\"hi\\"");|
    end

    test "escapes newlines" do
      assert DemoDirector.subtitle("line1\nline2") ==
               ~s|window.DemoDirector.subtitle("line1\\nline2");|
    end

    test "escapes backslashes" do
      assert DemoDirector.subtitle("a\\b") ==
               ~s|window.DemoDirector.subtitle("a\\\\b");|
    end

    test "passes null when given nil" do
      assert DemoDirector.subtitle(nil) == "window.DemoDirector.subtitle(null);"
    end
  end

  describe "highlight/1" do
    test "emits highlight JS for a demo-id" do
      assert DemoDirector.highlight("save-button") ==
               ~s|window.DemoDirector.highlight("save-button");|
    end

    test "passes null when given nil" do
      assert DemoDirector.highlight(nil) ==
               "window.DemoDirector.highlight(null);"
    end
  end

  describe "fill/2" do
    test "emits fill JS with id and value" do
      assert DemoDirector.fill("notes", "Patient stable.") ==
               ~s|window.DemoDirector.fill("notes", "Patient stable.");|
    end
  end

  describe "fill_typed/3" do
    test "emits awaited fillTyped JS with default per-char delay" do
      assert DemoDirector.fill_typed("notes", "hi") ==
               ~s|await window.DemoDirector.fillTyped("notes", "hi", 35);|
    end

    test "honors :per_char_ms option" do
      assert DemoDirector.fill_typed("notes", "hi", per_char_ms: 80) ==
               ~s|await window.DemoDirector.fillTyped("notes", "hi", 80);|
    end
  end

  describe "click/1" do
    test "emits click JS for a demo-id" do
      assert DemoDirector.click("save-button") ==
               ~s|window.DemoDirector.click("save-button");|
    end
  end

  describe "wait/1" do
    test "emits await Promise with the given timeout" do
      assert DemoDirector.wait(750) ==
               "await new Promise(r => setTimeout(r, 750));"
    end
  end
end
