# Demo Director

> Author with Tidewave, play back in your LiveView app.

`demo_director` is the loop between an AI agent and a saved product demo:
the agent drives your Phoenix LiveView app live through
[Tidewave Web](https://tidewave.ai)'s `browser_eval` tab while you watch
and refine; you save the resulting sequence to `priv/demos/<name>.exs`;
your team replays it later — from a web page, from a Mix task, from a
`<script>` tag in onboarding docs.

The runtime drives the page hands-off: a yellow subtitle bar narrates
what's happening word by word, a red highlight ring tracks the next
element, and characters get typed into form fields at a readable speed.

Tidewave is only needed during *authoring*. Replay works against any
Phoenix LiveView app with `demo_director` installed; the runtime
dependency is `phoenix_live_view` and nothing more.

## What it isn't

This is **not** a guided-tour library like
[shepherd.js](https://shepherdjs.dev), [intro.js](https://introjs.com), or
[driver.js](https://driverjs.com). Those wait for the user to click each
step in turn. `demo_director` is the opposite: the runtime *is* the
clicker. The user watches; the demo plays itself, end-to-end. Use it for
sales demos, screencast replacement, onboarding videos that you want to
keep in sync with the live app, and quick "look at this feature" links you
can paste into Slack.

If you want a tour where the user drives, use shepherd / driver / intro.
If you want a movie of your app that runs against the real DOM, use this.

## What's in the package

- **Six top-level helpers** — `subtitle/1`, `highlight/1`, `fill/2`,
  `fill_typed/3`, `click/1`, `wait/1` — each emits a JavaScript string
  that the runtime evals (or that gets saved into a `.exs` script).
- **A HEEx attribute helper** — `demo_id/1` — that drops a `data-demo-id`
  on any element, so selectors stay stable when LiveView patches the DOM.
- **An overlay component** — `<.demo_director_overlay />` — that renders
  the subtitle bar, highlight ring, and the package's CSS + JS.
- **A router macro** — `demo_director "/director"` — that mounts the
  static-asset plug, the playback channel, and the demos listing page at
  the path of your choice (default `/demo-director`).
- **A web demos browser** at `<mount>/demos` — lists every saved demo
  with a Play button per row.
- **A Mix task** — `mix demo_director.play <name>` — replays a saved
  demo against the running dev server, navigating the browser to the
  demo's starting route if needed.
- **An Igniter-based install task** — `mix igniter.install demo_director` —
  that wires the router macro and seeds your `AGENTS.md` / `CLAUDE.md`
  with the agent contract.

## Two ways to drive a demo

1. **Live, by an agent.** The agent emits helper calls into Tidewave Web's
   `browser_eval` tab as the user prompts a tour. Useful for exploration
   and for authoring.
2. **Replayable, from a saved `.exs`.** Once a demo is good, save the call
   sequence to `priv/demos/<name>.exs`. Anyone can replay it from
   `<mount>/demos` (one click) or `mix demo_director.play <name>` (one
   command) — no agent in the loop, no LLM in the runtime path.

Selectors stay stable through `data-demo-id`, so the same script produces
the same actions every run.

## Quick start

### Add to your Phoenix app

```elixir
# mix.exs
def deps do
  [
    {:demo_director, "~> 0.1", only: :dev},
    {:igniter, "~> 0.6", only: :dev}
  ]
end
```

Then:

```bash
mix deps.get
mix igniter.install demo_director
```

The install task wires the router macro, seeds your AGENTS.md / CLAUDE.md
with the agent contract, and prints a reminder to add the overlay component
to your dev-time root layout.

### Or wire it up by hand

A few small additions to your app, all gated behind the standard Phoenix
`:dev_routes` flag.

**1. Mount the routes** in `router.ex`. The static-asset / play / demos
plug must NOT go through `protect_from_forgery`, so use a bare scope:

```elixir
if Application.compile_env(:my_app, :dev_routes) do
  import DemoDirector.Router

  scope "/dev" do
    demo_director "/director"
  end
end
```

**2. Add the playback socket** to your endpoint, alongside the existing
`Phoenix.LiveView.Socket`:

```elixir
socket "/director/socket", DemoDirector.PlaybackSocket,
  websocket: true,
  longpoll: false
```

**3. Tell the package which PubSub server you use** (typically in
`config/dev.exs`):

```elixir
config :demo_director, pubsub: MyApp.PubSub
```

**4. Render the overlay** in your dev-time root layout
(`lib/my_app_web/components/layouts/root.html.heex`):

```heex
<DemoDirector.Components.demo_director_overlay />
```

**5. Tag interactive elements** with `data-demo-id`:

```heex
import DemoDirector.HEEx

~H"""
<button {demo_id("save-prescription")}>Save</button>
"""
```

### Direct a demo live (with an AI agent)

If you have Tidewave Web or any other tool that gives an AI agent a
`browser.eval`-equivalent surface, the agent can drive a demo live. Paste a
sequence of helper calls (the agent's prompts produce these for you):

```js
window.DemoDirector.subtitle("Let's add a prescription.");
await new Promise(r => setTimeout(r, 1500));
window.DemoDirector.highlight("save-prescription");
await new Promise(r => setTimeout(r, 800));
await window.DemoDirector.fillTyped("medication-search", "Atenolol", 35);
await new Promise(r => setTimeout(r, 1200));
window.DemoDirector.click("save-prescription");
```

Or generated from Elixir:

```elixir
[
  DemoDirector.subtitle("Let's add a prescription."),
  DemoDirector.wait(1500),
  DemoDirector.highlight("save-prescription"),
  DemoDirector.wait(800),
  DemoDirector.fill_typed("medication-search", "Atenolol"),
  DemoDirector.wait(1200),
  DemoDirector.click("save-prescription")
]
|> Enum.join("\n")
```

### Replay a saved demo

Once a demo is good, save it to `priv/demos/<name>.exs`. The first comments
in the file double as metadata:

```elixir
# Demo: add a prescription for Mrs. Lee.
# @start_at "/patients/mrs-lee"

alias DemoDirector, as: DD

steps = [
  DD.subtitle("Let's add a prescription."),
  DD.wait(1500),
  DD.highlight("add-prescription-button"),
  DD.wait(800),
  DD.click("add-prescription-button"),
  # …
]

IO.puts(Enum.join(steps, "\n"))
```

Then either:

- **Open `<mount>/demos`** in your browser (e.g.
  `http://localhost:4000/dev/director/demos`) to see every saved demo with
  a Play button. Clicking Play navigates the browser to the demo's
  `@start_at` and runs it.
- **Run `mix demo_director.play <name>`** from a second terminal. The task
  prints a clickable URL like
  `http://localhost:4000/dev/director/demos/<name>/play`. Opening it
  stashes the demo in `sessionStorage`, redirects to `@start_at`, and the
  overlay there picks it up on load.

### Author a demo by hand

You don't need an agent to write a demo — the helpers compose like any
other Elixir code. Pick a starting route, list the elements you want to
walk through, and turn each step into a helper call:

```elixir
# priv/demos/onboarding.exs
# Demo: walk a new user through their first post.
# @start_at "/"

alias DemoDirector, as: DD

steps = [
  DD.subtitle("Welcome! Let's create your first post."),
  DD.wait(1800),

  DD.subtitle("Click 'New post' to get started."),
  DD.highlight("new-post-button"),
  DD.wait(900),
  DD.click("new-post-button"),
  DD.wait(1200),

  DD.subtitle("Title goes here. Try something descriptive."),
  DD.highlight("post-title-input"),
  DD.wait(700),
  DD.fill_typed("post-title-input", "My first post"),
  DD.wait(1500),

  DD.subtitle("That's the basics — fill in the rest at your own pace."),
  DD.highlight(nil),
  DD.wait(2400),
  DD.subtitle(nil)
]

IO.puts(Enum.join(steps, "\n"))
```

Two things to know:

1. **Every interactive element you target needs `data-demo-id`** — add it
   in your HEEx with the `demo_id/1` helper. Don't reach for CSS
   selectors; `data-demo-id` is the contract that lets demos survive
   LiveView's morphdom.
2. **Pace generously.** Subtitles reveal word-by-word at ~110ms/word —
   the trailing `wait` should be at least the reveal duration plus a
   beat. `fill_typed` defaults to 35ms/char, which reads naturally; lower
   for filler text, higher for content the viewer is meant to read.

Test by saving and opening `<mount>/demos`. The new entry shows up
automatically.

## Try the example app

The package ships with a minimal Phoenix LiveView blog app — a post
composer, a public reader view, and a comments section — wired up in
`dev.exs` so the package can be smoke-tested end-to-end against a real
running app without a separate Mix project.

```bash
mix deps.get
mix dev
```

Open <http://localhost:4000/dev/director/demos> and click Play on any of
the four bundled demos. Or run them from a second terminal:

```bash
mix demo_director.play compose_post
mix demo_director.play fix_validation_errors
mix demo_director.play search_drafts
mix demo_director.play reader_comment
```

The four demos exercise:

- `compose_post.exs` — fill out every guardrail-checked field, watch the
  bar go green, click publish
- `fix_validation_errors.exs` — open a half-written draft, fix each
  validation error in turn
- `search_drafts.exs` — live search filtering as `fill_typed` fires
  `phx-change` per keystroke
- `reader_comment.exs` — open a published post, leave a comment, watch
  the comment stream in via Phoenix.PubSub

## Compatibility

| Component | Required | Tested with |
|---|---|---|
| Elixir | `~> 1.15` | 1.18.x, 1.19.x |
| Phoenix | via `phoenix_live_view ~> 1.0` | 1.7.x, 1.8.x |
| Phoenix.LiveView | `~> 1.0` | 1.1.x |
| Tidewave | **optional** — only for live agent authoring; replay works without it | tested against `tidewave ~> 0.5` (specifically 0.5.6) |
| Igniter | `~> 0.6`, optional (only used by the install task) | 0.7.x |

## Selector contract

All helpers default to `data-demo-id` lookups via the `demo_id/1` HEEx
helper. The agent (or human script author) should never invent a CSS
selector — `:nth-child` and deep descendant chains are exactly what the
convention exists to avoid. If a target lacks `data-demo-id`, add one.

## Production stripping

The integration is gated by Phoenix's standard
`Application.compile_env(:my_app, :dev_routes)` pattern — the same flag
that gates `live_dashboard` and `Plug.Swoosh.MailboxPreview`. With the
flag off (the default in `:prod`), the router macro never compiles, the
static-asset plug is never mounted, and the overlay component renders
nothing. The `data-demo-id` attributes themselves still render — a few
extra bytes per element, no outgoing requests, no JS hooks, no overlay.

If you want stricter prod stripping, wrap your `demo_id/1` call sites in
your own `Mix.env() == :dev` block; this helper deliberately stays
side-effect-free.

## Caveats

**Demos write real records.** This is not a dry run against your DB. A
demo that types into a form and clicks Submit creates real records, sends
real emails, queues real jobs. Keep the package gated behind `:dev_routes`
(or your equivalent), and only enable it in environments where it's safe
for forms to hit the real data layer. See `MEMORY.md` for the deferred
plan to add a sandboxed demo-session primitive.

**Localhost-only playback by default.** The `<mount>/play` HTTP endpoint
that receives broadcasts from `mix demo_director.play` rejects
non-loopback IPs. If you want demos to be playable from a non-localhost
staging instance, that gate needs to be relaxed — currently requires a
code change.

## Troubleshooting

**Clicking Play does nothing / the overlay never appears.**
Check the overlay is rendered in your dev-time root layout
(`<DemoDirector.Components.demo_director_overlay />`) and that the router
macro is mounted under a non-`:browser`-piped scope. The static asset
plug must NOT pass through `protect_from_forgery` — the playback POST is
cross-origin from the agent's perspective and CSRF will reject it.

**`/director/socket` 404s in the browser console.**
Add the playback socket to your endpoint, alongside the existing
`Phoenix.LiveView.Socket`:

```elixir
socket "/director/socket", DemoDirector.PlaybackSocket,
  websocket: true,
  longpoll: false
```

**Channel join fails with `KeyError: key :pubsub not found`.**
Tell the package which PubSub server to broadcast on:

```elixir
config :demo_director, pubsub: MyApp.PubSub
```

**The Mix task says "could not find a DemoDirector mount."**
The probe couldn't find a live server. Check `mix dev` is running, and
that `DD_HOST` (default `http://localhost:4000`) points at the right
host:port. If you're using a non-default mount path, pass `--url`
explicitly.

**Subtitle reveals out of sync with the action / the demo runs in
parallel.**
Make sure `fill_typed` calls are `await`ed on the JS side (the helper
emits `await window.DemoDirector.fillTyped(...)` automatically as of
v0.1; older saved scripts may need re-generating).

**Typed characters get dropped mid-typing.**
The runtime tracks its own typing buffer and self-corrects DOM
mismatches on the final character (with a `console.warn` if it had to
correct). If you see warnings, the host page is morphing the input
mid-typing — usually fine, but worth confirming the field has stable
identity across re-renders.

**Demo runs in a background tab feels glacial.**
That's the browser's `setTimeout` throttling for inactive tabs. The
demo isn't broken; it'll resume normal speed when the tab returns to the
foreground.

## License

Apache-2.0. See [LICENSE.md](LICENSE.md).
