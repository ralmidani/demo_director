<!-- BEGIN demo_director -->
## Driving product demos with DemoDirector

This project uses [`demo_director`](https://hex.pm/packages/demo_director)
to direct AI-authored product demos that anyone can replay later. When a
developer asks you to walk them (or someone else) through a feature,
follow the protocol below.

### What you have

A small Elixir API that emits JavaScript strings:

```elixir
DemoDirector.subtitle("First we'll add a diagnosis.")
DemoDirector.highlight("save-prescription")  # nil to clear
DemoDirector.fill("uuid-field", "abc123")    # instant
DemoDirector.fill_typed("notes", "Patient stable.", per_char_ms: 35)
DemoDirector.click("save-prescription")
DemoDirector.wait(800)
```

Each call returns a JS string. Run it by passing it to Tidewave's
`browser_eval` (or any equivalent in-browser evaluator). Wrap a sequence
in an `async` function so `await DemoDirector.wait/1` works.

### The selector contract

The runtime resolves targets in two passes: first as `data-demo-id`,
then — if no match — as a raw CSS selector via `document.querySelector`.
So all of these work:

```elixir
DemoDirector.click("save-prescription")     # data-demo-id="save-prescription"
DemoDirector.click("#save-prescription")    # element id
DemoDirector.click(".btn-primary")          # class
DemoDirector.click("button[type=submit]")   # attribute
```

**Pick the most stable handle that already exists in the host's
markup** — semantic ids the host already uses for in-page navigation,
form-field ids that `<label for="">` points at, distinctive attributes.
Those are the ones the host has the strongest incentive to keep stable.

Reach for `data-demo-id` (via the `demo_id/1` HEEx helper) when no such
handle exists, or when the element you want to target has nothing
distinctive about it (icon buttons, repeated rows). If you're tagging
markup specifically for a demo and have permission from the developer,
add it like this:

```heex
<button {demo_id("save-prescription")}>Save</button>
```

`data-demo-id` lookup runs first, so a deliberately-tagged element wins
over any unrelated CSS-selector match.

**Avoid `:nth-child` chains and deep descendant paths** — those break
the moment a sibling moves. If the only way you can target something is
a structural selector, ask for a stable handle instead.

### A typical demo loop

```js
// Tidewave browser_eval (top-level await is fine)
window.DemoDirector.subtitle("Let's add a new prescription.");
await new Promise(r => setTimeout(r, 1500));
window.DemoDirector.highlight("medication-search");
await new Promise(r => setTimeout(r, 800));
await window.DemoDirector.fillTyped("medication-search", "Atenolol", 35);
await new Promise(r => setTimeout(r, 1200));
window.DemoDirector.click("medication-result-atenolol");
```

Or, equivalently, generated from Elixir on the agent side:

```elixir
[
  DemoDirector.subtitle("Let's add a new prescription."),
  DemoDirector.wait(1500),
  DemoDirector.highlight("medication-search"),
  DemoDirector.wait(800),
  DemoDirector.fill_typed("medication-search", "Atenolol"),
  DemoDirector.wait(1200),
  DemoDirector.click("medication-result-atenolol")
]
|> Enum.join("\n")
```

### Pacing

* **~1.5s per subtitle line** so a reader can finish it. The runtime
  reveals subtitles word-by-word at ~110ms/word; the trailing wait should
  be at least the reveal duration plus a beat.
* **~800ms after a highlight** before the next action — gives the eye
  time to catch up to the ring.
* **`fill_typed` defaults to 35ms per char** — readable, not glacial.
  Lower for filler text (UUIDs, prefilled fields), higher for content the
  viewer should actually read.

### What NOT to do

* Don't manipulate page state outside the demo flow (no auth bypass, no
  database fixtures, no DOM injection). The demo runs against the app as
  the user would experience it.
* Don't skip subtitles. The viewer needs narration to follow what's
  happening; a sequence of clicks with no commentary is incomprehensible.
* Don't chain more than ~6 actions without checking in. Demos drift from
  user intent fast; surface progress and ask what to cover next.

### Saving demos for replay

When the developer says *"save this as `<name>`"*, write the demo to
`priv/demos/<name>.exs` as a runnable script that prints the JS sequence:

```elixir
# Demo: short title for the listing page.
# @start_at "/path/where/the/demo/expects/the/user/to/be"

alias DemoDirector, as: DD

steps = [
  DD.subtitle("Let's …"),
  DD.wait(1500),
  DD.highlight("save-prescription"),
  DD.wait(800),
  DD.click("save-prescription")
]

IO.puts(Enum.join(steps, "\n"))
```

The two leading-comment headers matter:

* `# Demo: …` becomes the demo's title on the `/demos` listing page.
* `# @start_at "/path"` declares where the demo expects the user to be
  before it runs. Both the listing-page Play button and
  `mix demo_director.play <name>` use this to navigate the browser to
  the right place before running.

Once saved, anyone can replay the demo from `<mount>/demos` (one click)
or via `mix demo_director.play <name>` (prints a clickable URL).
<!-- END demo_director -->
