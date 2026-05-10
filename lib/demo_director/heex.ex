defmodule DemoDirector.HEEx do
  @moduledoc """
  HEEx-template helpers for tagging elements as demo-targetable.

  Import this module wherever you author HEEx and call `demo_id/1` to
  emit a `data-demo-id` attribute via the spread syntax:

      import DemoDirector.HEEx

      ~H\"\"\"
      <button {demo_id("save-prescription")}>Save</button>
      \"\"\"

  Renders as:

      <button data-demo-id="save-prescription">Save</button>

  ## Why an attribute helper

  An `id="save-prescription"` would collide with whatever the LiveView
  / form already uses for DOM id (forms, label-for, accessibility).
  `data-demo-id` is the established testing-and-tooling-attribute
  pattern (mirrors `data-testid` from React-land), survives DOM diffs,
  doesn't touch CSS selectors, and is trivially queryable from JS.

  ## Selector stability

  The agent's preferred selector is always `data-demo-id`. If it
  needs to target something the template doesn't yet expose, it
  should ask you to add the attribute rather than invent a CSS
  selector — `:nth-child` and deep descendant chains are exactly
  what this helper exists to avoid.
  """

  @doc """
  Returns a keyword list with a single `data-demo-id` attribute.

  Designed for the HEEx attribute-spread `{...}` form:

      <button {demo_id("save-prescription")}>Save</button>

  ## Production stripping

  This package is gated host-side via the standard
  `Application.compile_env(:host_app, :dev_routes)` pattern: in prod
  builds with that flag off, the host's `demo_director` router
  macro never compiles, no assets are served, the overlay component
  renders empty. The `data-demo-id` attributes themselves DO still
  render in the HTML — but a few extra bytes per element with no
  outgoing requests, no JS hooks, no overlay is the cheapest path
  to keeping templates env-portable.

  If you want stricter prod stripping, wrap your call site in your
  own `if Mix.env() == :dev` block; this helper deliberately stays
  side-effect-free.
  """
  @spec demo_id(String.t()) :: [{atom(), String.t()}]
  def demo_id(id) when is_binary(id) do
    [{:"data-demo-id", id}]
  end
end
