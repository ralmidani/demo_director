defmodule DemoDirector.Components do
  @moduledoc """
  HEEx components for the DemoDirector overlay.

  Mount once on a layout (typically the dev-time root layout):

      import DemoDirector.Components

      ~H\"\"\"
      <.demo_director_overlay />
      \"\"\"

  When the host app's router has called `demo_director/1` (the
  macro from `DemoDirector.Router`), this component renders:

    * a `<link rel="stylesheet">` pointing at the macro-mounted CSS
    * a `<script>` pointing at the matching JS
    * the subtitle and highlight DOM nodes the agent's emitted JS
      will manipulate

  When the macro has NOT been called (e.g., a prod build that gates
  the macro behind `:dev_routes`), the component renders nothing.
  This is the belt-and-suspenders strip — even if a layout
  accidentally calls the component in prod, it stays inert.
  """

  use Phoenix.Component

  @doc """
  Renders the DemoDirector overlay (subtitle bar + highlight
  ring) and includes the package's CSS + JS.

  Renders empty when the host app has not invoked the
  `demo_director/1` router macro (no mount path registered).
  """
  attr :id_prefix, :string,
    default: "demo-director",
    doc: "Prefix for the DOM ids of the subtitle and highlight nodes."

  def demo_director_overlay(assigns) do
    case Application.get_env(:demo_director, :mount_path) do
      nil ->
        ~H""

      mount_path ->
        assigns =
          assigns
          |> assign(:mount_path, mount_path)
          |> assign(
            :socket_path,
            Application.get_env(:demo_director, :socket_path, "/director/socket")
          )

        ~H"""
        <link rel="stylesheet" href={"#{@mount_path}/demo_director.css"} />
        <script src={"#{@mount_path}/demo_director.js"}></script>

        <div
          id={"#{@id_prefix}-subtitle"}
          class="demo-director__subtitle"
          aria-live="polite"
          dir="auto"
          data-dd-socket={@socket_path}
          data-dd-mount={@mount_path}
          hidden
        ></div>

        <div
          id={"#{@id_prefix}-highlight"}
          class="demo-director__highlight"
          aria-hidden="true"
          hidden
        ></div>
        """
    end
  end
end
