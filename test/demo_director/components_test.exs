defmodule DemoDirector.ComponentsTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias DemoDirector.Components

  setup do
    original = Application.get_env(:demo_director, :mount_path)
    on_exit(fn -> Application.put_env(:demo_director, :mount_path, original) end)
    :ok
  end

  describe "demo_director_overlay/1" do
    test "renders nothing when no mount path is registered" do
      Application.delete_env(:demo_director, :mount_path)

      html = render_component(&Components.demo_director_overlay/1, %{})

      assert html == ""
    end

    test "renders link, script, and overlay nodes when mount path is set" do
      Application.put_env(:demo_director, :mount_path, "/dev/director")

      html = render_component(&Components.demo_director_overlay/1, %{})

      assert html =~ ~s|href="/dev/director/demo_director.css"|
      assert html =~ ~s|src="/dev/director/demo_director.js"|
      assert html =~ ~s|id="demo-director-subtitle"|
      assert html =~ ~s|id="demo-director-highlight"|
      assert html =~ ~s|class="demo-director__subtitle"|
      assert html =~ ~s|class="demo-director__highlight"|
    end

    test "honors :id_prefix override" do
      Application.put_env(:demo_director, :mount_path, "/director")

      html = render_component(&Components.demo_director_overlay/1, %{id_prefix: "my-demo"})

      assert html =~ ~s|id="my-demo-subtitle"|
      assert html =~ ~s|id="my-demo-highlight"|
    end
  end
end
