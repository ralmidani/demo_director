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
      Application.put_env(
        :demo_director,
        :mount_path,
        Phoenix.Router.scoped_path(__MODULE__, path)
      )

      forward(path, DemoDirector.Plug.Static)
    end
  end
end
