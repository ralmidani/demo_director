defmodule DemoDirector do
  @moduledoc """
  Direct AI-driven product demos for Phoenix apps, right from your
  Tidewave Web tab.

  DemoDirector gives an AI agent (or, eventually, a saved script)
  the seams to drive a Phoenix LiveView application as a guided tour:
  subtitled explanations appear in an overlay, the next element to
  interact with is highlighted, typing is slowed enough to read, and
  selectors stay stable via the `data-demo-id` convention.

  ## Concept

  The package is intentionally small. It does not run demos itself —
  it produces JavaScript strings that an agent passes to Tidewave's
  `browser_eval` (or any equivalent in-browser evaluator), plus HEEx
  components and JS/CSS that render the demo overlay in the page.

  Two layers:

  1. **Top-level helpers in this module** (`subtitle/1`, `highlight/1`,
     `fill/2`, `fill_typed/3`, `click/1`, `wait/1`) return JS source
     strings. The agent drives the demo by emitting them in sequence.
  2. **Overlay components in `DemoDirector.Components`** render
     the subtitle bar and highlight ring. Apps mount these once on a
     layout.

  ## Quick start

      # In your layout (Phoenix.Component or LiveView):
      import DemoDirector.Components

      ~H\"\"\"
      <.demo_director_overlay />
      \"\"\"

      # In your HEEx templates, mark interactive elements:
      import DemoDirector.HEEx

      ~H\"\"\"
      <button {demo_id("save-prescription")}>Save</button>
      \"\"\"

      # Then the agent emits, in sequence, things like:
      DemoDirector.subtitle("First we'll add a diagnosis.")
      DemoDirector.highlight("save-prescription")
      DemoDirector.fill_typed("notes", "Patient stable.")
      DemoDirector.click("save-prescription")

  Each return value is a JS string. The agent passes it to
  `browser.eval(...)` (Tidewave) or any evaluator with a JavaScript
  execution context for the page.

  ## Selectors

  All helpers default to `data-demo-id` lookups. To target an element
  the LiveView source doesn't yet expose, the agent should ask before
  inventing a CSS selector — fragile selectors (`:nth-child`, deep
  descendant chains) are exactly what `data-demo-id` exists to avoid.
  """

  @typedoc """
  A demo-id string. Maps to the value of a `data-demo-id` attribute
  on one or more elements in the rendered page.
  """
  @type demo_id :: String.t()

  @typedoc """
  Options accepted by typing-driven helpers.

    * `:per_char_ms` — delay between simulated keystrokes (default: 35).
  """
  @type type_opts :: [per_char_ms: pos_integer()]

  @doc """
  Sets the subtitle overlay text.

  Returns JS that finds the subtitle overlay (rendered by
  `DemoDirector.Components.demo_director_overlay/1`) and
  updates its text content.
  """
  @spec subtitle(String.t() | nil) :: String.t()
  def subtitle(nil), do: "window.DemoDirector.subtitle(null);"

  def subtitle(text) when is_binary(text) do
    "window.DemoDirector.subtitle(#{js_string(text)});"
  end

  @doc """
  Highlights the element with the given demo-id.

  Renders a focus ring around the matching element and scrolls it
  into view. Passing `nil` clears any active highlight.
  """
  @spec highlight(demo_id() | nil) :: String.t()
  def highlight(nil), do: "window.DemoDirector.highlight(null);"

  def highlight(id) when is_binary(id) do
    "window.DemoDirector.highlight(#{js_string(id)});"
  end

  @doc """
  Fills the element with the given demo-id with `value` instantly.

  Useful for fields where typing animation would distract — uuids,
  prefilled fields, anything the user shouldn't be drawn to.
  """
  @spec fill(demo_id(), String.t()) :: String.t()
  def fill(id, value) when is_binary(id) and is_binary(value) do
    "window.DemoDirector.fill(#{js_string(id)}, #{js_string(value)});"
  end

  @doc """
  Fills the element with the given demo-id one character at a time,
  dispatching input events between keystrokes.

  Default speed is 35ms per character. Pass `per_char_ms:` to
  override:

      DemoDirector.fill_typed("note", "Patient stable.", per_char_ms: 60)
  """
  @spec fill_typed(demo_id(), String.t(), type_opts()) :: String.t()
  def fill_typed(id, value, opts \\ [])
      when is_binary(id) and is_binary(value) and is_list(opts) do
    per_char = Keyword.get(opts, :per_char_ms, 35)

    "await window.DemoDirector.fillTyped(#{js_string(id)}, #{js_string(value)}, #{per_char});"
  end

  @doc """
  Clicks the element with the given demo-id.
  """
  @spec click(demo_id()) :: String.t()
  def click(id) when is_binary(id) do
    "window.DemoDirector.click(#{js_string(id)});"
  end

  @doc """
  Pauses for `ms` milliseconds. Useful between steps to let the user
  read a subtitle or watch a transition complete.

  Returned JS uses `await`, so the agent must wrap its sequence in
  an async function (Tidewave's `browser.eval` supports this).
  """
  @spec wait(pos_integer()) :: String.t()
  def wait(ms) when is_integer(ms) and ms > 0 do
    "await new Promise(r => setTimeout(r, #{ms}));"
  end

  # Inlined JSON-string encoding — avoids a Jason dependency.
  # Escapes quotes, backslashes, and the four common control chars.
  defp js_string(binary) when is_binary(binary) do
    escaped =
      binary
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")
      |> String.replace("\t", "\\t")

    "\"" <> escaped <> "\""
  end
end
