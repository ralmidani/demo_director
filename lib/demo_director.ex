defmodule DemoDirector do
  @moduledoc """
  Reproducible, replayable demos for Phoenix LiveView — author
  reusable scripts, with or without AI.

  DemoDirector lets you record a narrated walkthrough of a Phoenix
  LiveView app as a tiny Elixir script. Anyone can replay it later —
  against the real app, against real data, with no AI in the runtime
  path. During playback, a subtitle bar narrates word-by-word, a
  highlight ring tracks the next element, and characters get typed
  into form fields at a readable speed.

  See [the README](readme.html) for the full integration walkthrough.

  ## Concept

  The package is intentionally small. The helpers in this module
  return JavaScript-string fragments that compose, via newline-joined
  `IO.puts`, into a script the runtime evaluates. Author by hand or
  let an AI agent drive the helpers live (e.g. via
  [Tidewave Web](https://tidewave.ai)'s `browser_eval`); either way
  the saved `.exs` is the durable artifact.

  Two layers:

    1. **Top-level helpers in this module** (`subtitle/1`,
       `highlight/1`, `fill/2`, `fill_typed/3`, `click/1`, `wait/1`)
       — each emits one JS statement.
    2. **Overlay components in `DemoDirector.Components`** — render
       the subtitle bar and highlight ring plus load the runtime.
       Host apps mount this once on a dev-time root layout.

  ## Quick start

      # In your dev-time root layout:
      import DemoDirector.Components

      ~H\"\"\"
      <.demo_director_overlay />
      \"\"\"

      # Save a demo at priv/demos/onboarding.exs:
      # Demo: walk a new user through their first post.
      # @start_at "/"

      alias DemoDirector, as: DD

      steps = [
        DD.subtitle("Let's add a new post."),
        DD.wait(1500),
        DD.highlight("#new-post"),
        DD.click("#new-post")
      ]

      IO.puts(Enum.join(steps, "\\n"))

  ## Selectors

  The runtime resolves targets in two passes: `data-demo-id` first,
  then `document.querySelector`. Prefer the most stable handle that
  already exists in the host's markup (semantic ids, label-pointed
  form ids, distinctive attributes). Reach for `data-demo-id` (via
  `DemoDirector.HEEx.demo_id/1`) only when no such handle exists.
  Avoid `:nth-child` chains and deep descendant paths.
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
  `DemoDirector.Components.demo_director_overlay/1`) and updates its
  text content. The runtime reveals the text word-by-word at
  ~110ms/word; pace following `wait/1` calls accordingly.

  Pass `nil` to clear an active subtitle.

  ## Examples

      iex> DemoDirector.subtitle("Let's add a diagnosis.")
      ~s|window.DemoDirector.subtitle("Let's add a diagnosis.");|

      iex> DemoDirector.subtitle(nil)
      "window.DemoDirector.subtitle(null);"
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
  dispatching `input` and `keyup` events between keystrokes.

  The emitted JS is awaited so subsequent steps don't fire before
  typing completes.

  ## Options

    * `:per_char_ms` — delay between simulated keystrokes
      (default: `35`). Lower for filler text the viewer shouldn't
      linger on; raise for content the viewer is meant to read.

  ## Examples

      iex> DemoDirector.fill_typed("note", "Patient stable.")
      ~s|await window.DemoDirector.fillTyped("note", "Patient stable.", 35);|

      iex> DemoDirector.fill_typed("note", "...", per_char_ms: 60)
      ~s|await window.DemoDirector.fillTyped("note", "...", 60);|

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

  Returned JS uses `await`, so an AI agent driving the demo via
  `browser_eval` must wrap its sequence in an async function (most
  do this automatically; Tidewave's `browser.eval` supports it). The
  saved-script playback runtime always wraps in async.

  ## Examples

      iex> DemoDirector.wait(750)
      "await new Promise(r => setTimeout(r, 750));"

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
