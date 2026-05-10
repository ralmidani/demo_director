defmodule DemoDirector.RouterTest do
  use ExUnit.Case, async: false

  # The router macro registers `:demo_director`'s `:mount_path` env at
  # module-load time via an `@on_load` callback. These tests compile
  # fixture router modules at runtime, then assert the env reflects what
  # the macro should have written.
  #
  # `async: false` because every test mutates the shared application env.

  setup do
    original = Application.get_env(:demo_director, :mount_path)
    on_exit(fn -> Application.put_env(:demo_director, :mount_path, original) end)
    :ok
  end

  describe "demo_director/1 macro" do
    test "registers the mount path at module-load time, not just compile time" do
      Application.delete_env(:demo_director, :mount_path)

      defmodule TopLevelRouter do
        use Phoenix.Router
        import DemoDirector.Router

        demo_director("/director")
      end

      assert Application.get_env(:demo_director, :mount_path) == "/director"
    end

    test "honors a wrapping scope's path prefix" do
      Application.delete_env(:demo_director, :mount_path)

      defmodule ScopedRouter do
        use Phoenix.Router
        import DemoDirector.Router

        scope "/dev" do
          demo_director("/director")
        end
      end

      assert Application.get_env(:demo_director, :mount_path) == "/dev/director"
    end

    test "uses the default path when called without arguments" do
      Application.delete_env(:demo_director, :mount_path)

      defmodule DefaultPathRouter do
        use Phoenix.Router
        import DemoDirector.Router

        demo_director()
      end

      assert Application.get_env(:demo_director, :mount_path) == "/demo-director"
    end

    test "exposes a 0-arity registration function so @on_load can call it" do
      defmodule InspectableRouter do
        use Phoenix.Router
        import DemoDirector.Router

        demo_director("/director")
      end

      # The macro generates this function as the @on_load target. If it
      # disappears or changes arity, every host router silently loses
      # its mount-path registration — keep the contract pinned.
      assert function_exported?(InspectableRouter, :__demo_director_register_mount_path__, 0)

      # Calling the registration function must always set the env to
      # the macro-baked path (not raise, not no-op).
      Application.delete_env(:demo_director, :mount_path)
      assert :ok = InspectableRouter.__demo_director_register_mount_path__()
      assert Application.get_env(:demo_director, :mount_path) == "/director"
    end
  end
end
