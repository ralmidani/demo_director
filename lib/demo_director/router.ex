defmodule DemoDirector.Router do
  @moduledoc """
  Router macro for mounting DemoDirector's static assets and
  registering the mount path so the overlay component can construct
  asset URLs.

  Mirrors the `Phoenix.LiveDashboard.Router.live_dashboard/2` pattern.

  ## Usage

  Inside your host app's `router.ex`, gated by the standard Phoenix
  dev-routes flag:

      if Application.compile_env(:my_app, :dev_routes) do
        import Phoenix.LiveDashboard.Router
        import DemoDirector.Router

        scope "/dev" do
          pipe_through :browser

          live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry
          forward "/mailbox", Plug.Swoosh.MailboxPreview
          demo_director "/director"
        end
      end

  This mounts the package's CSS + JS at `/dev/director/*` (in this
  example) and tells the overlay component where to point its
  `<link>` and `<script>` tags.

  Without arguments, the default mount path is `/demo-director`:

      demo_director()
  """

  @default_path "/demo-director"

  @doc """
  Forwards the given path to DemoDirector's static-asset plug
  and stores the path in `:demo_director`'s application env so
  `DemoDirector.Components.demo_director_overlay/1` can
  construct correct asset URLs.

  Defaults to `"/demo-director"`.
  """
  defmacro demo_director(path \\ @default_path) do
    quote bind_quoted: [path: path] do
      forward(path, DemoDirector.Plug.Static)

      # Compute the full scoped path at compile time (where
      # `Phoenix.Router.scoped_path/2` works — it reads scope info via
      # `Module.get_attribute/2`), bake it into a module attribute,
      # then register it at module-load time via `@on_load`.
      #
      # Why not call `Application.put_env` inline? It would run at
      # compile time, writing to whichever BEAM is doing the compile.
      # During Mix-driven workflows that's often a short-lived compiler
      # subprocess whose env dies before the dev server's runtime BEAM
      # ever sees it — so the overlay component would find
      # `mount_path: nil` at runtime and render empty.
      #
      # `@on_load` runs every time the router module is loaded into a
      # BEAM (cold boot, hot reload, code purge + reload), so the env
      # is always present at runtime regardless of how the router got
      # compiled.
      @demo_director_full_path Phoenix.Router.scoped_path(__MODULE__, path)
      @on_load :__demo_director_register_mount_path__

      def __demo_director_register_mount_path__ do
        Application.put_env(:demo_director, :mount_path, @demo_director_full_path)
        :ok
      end
    end
  end
end
