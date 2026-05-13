# Demo Director

[![Hex.pm](https://img.shields.io/hexpm/v/demo_director.svg)](https://hex.pm/packages/demo_director)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-blue)](https://hexdocs.pm/demo_director)

> Reproducible, replayable demos for Phoenix LiveView — author reusable scripts, with or without AI.

`demo_director` lets you record a narrated walkthrough of your Phoenix
LiveView app as a tiny Elixir script. Anyone can replay it later —
against the real app, against real data, with no AI in the runtime path.

During playback, a yellow subtitle bar narrates what's happening word
by word, a red highlight ring tracks the next element, and characters
get typed into form fields at a readable speed.

Two authoring paths, same output:

- **By hand.** Write the `.exs` directly. The format is a flat sequence
  of helper calls — easy to read, easy to edit, easy to diff.
- **By AI.** Hand the helper API to an agent that can drive your
  browser (e.g., [Tidewave Web](https://tidewave.ai)'s `browser_eval`,
  or any equivalent in-browser evaluator). The agent runs the demo live
  while you watch; when you're happy, save an Elixir script that emits
  the same JS calls the agent ran.

The runtime dependency is `phoenix_live_view` and nothing more — no LLM
gateway, no API keys, no internet at replay time.

## What it isn't

This is **not** a guided-tour library like
[shepherd.js](https://shepherdjs.dev), [intro.js](https://introjs.com), or
[driver.js](https://driverjs.com). Those wait for the user to click each
step in turn. `demo_director` is the opposite: the runtime *is* the
clicker. The user watches; the demo plays itself, end-to-end. Use it for
sales demos, onboarding walkthroughs you want to keep in sync with the
live app, and quick "look at this feature" links you can paste into
Slack.

If you want a tour where the user drives, use shepherd / driver / intro.
If you want a script that plays your app autonomously against the real
DOM, use this.

## What's in the package

- **Six top-level helpers** — `subtitle/1`, `highlight/1`, `fill/2`,
  `fill_typed/3`, `click/1`, `wait/1` — each emits a JavaScript string
  that the runtime evals (or that gets saved into a `.exs` script).
- **A HEEx attribute helper** — `demo_id/1` — that drops a `data-demo-id`
  on any element, so selectors stay stable when LiveView patches the DOM.
- **An overlay component** — `<.demo_director_overlay />` — that renders
  the subtitle bar, highlight ring, and the package's CSS + JS.
- **A router macro** — `demo_director "/demo-director"` — that mounts the
  static-asset plug, the playback channel, and the demos listing page at
  the path of your choice (default `/demo-director`).
- **A web demos browser** at `<mount>` (also `<mount>/demos`) — lists
  every saved demo with a Play button per row.
- **A Mix task** — `mix demo_director.play <name>` — replays a saved
  demo against the running dev server, navigating the browser to the
  demo's starting route if needed.
- **An Igniter-based install task** — `mix igniter.install demo_director` —
  that wires the router macro and seeds your `AGENTS.md` / `CLAUDE.md`
  with the agent contract.

Selectors are passed through to `document.querySelector` — pick whatever
already-stable handle the host markup gives you (an id, an attribute,
or `data-demo-id` if you need a dedicated tag). See **Selector contract**
below for the full picture.

## Quick start

### Add to your Phoenix app

`demo_director` assumes the host app already has a working Phoenix
LiveView setup (a `Phoenix.LiveView.Socket` declaration in the
endpoint, a router, and the standard layouts). The installer doesn't
bootstrap LiveView from scratch.

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

The install task does four things automatically:

1. Wires the router macro under an `if Application.compile_env(:my_app, :dev_routes)` block.
2. Adds the playback socket to your endpoint, after the existing `Phoenix.LiveView.Socket`.
3. Adds `config :demo_director, pubsub: <OtpApp>.PubSub` to `config/dev.exs` (using the conventional `mix phx.new` PubSub name; if your PubSub server is named differently, edit the value after install).
4. Seeds `AGENTS.md` / `CLAUDE.md` with the agent contract.

It then prints a reminder for the one step that stays manual: rendering
the overlay component in your dev-time root layout.

### Or wire it up by hand

A few small additions to your app, all gated behind the standard Phoenix
`:dev_routes` flag.

**1. Mount the routes** in `router.ex`. The static-asset / play / demos
plug must NOT go through `protect_from_forgery`, so use a bare scope:

```elixir
if Application.compile_env(:my_app, :dev_routes) do
  import DemoDirector.Router

  scope "/dev" do
    demo_director "/demo-director"
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

This step stays manual on purpose. The other wiring lives in
`.ex` files — Igniter can edit those via the Elixir AST and keep the
edit idempotent across re-runs. Root layouts are HEEx, and HEEx isn't
parsed as an AST the way Elixir is, so editing it programmatically
means string-level surgery against a file users frequently customize
(branding, analytics, custom font links, conditional `<body>` markup).
The risk of corrupting a heavily-edited layout outweighed the
convenience of auto-injecting one line. The component itself is
already prod-safe — it returns empty markup whenever the
`demo_director/1` router macro hasn't registered a mount path (which
is exactly what happens when `:dev_routes` is off), so the line can
sit unconditionally inside `<body>` and you won't see it in
production.

**5. (When needed) tag interactive elements** with `data-demo-id`.
Most existing markup is already targetable — semantic ids
(`<section id="vitals">`), form ids the labels point at, and
attribute selectors all work. Reach for `data-demo-id` only when no
such handle exists, or when an element would be hard to disambiguate
otherwise:

```heex
import DemoDirector.HEEx

~H"""
<button {demo_id("save-prescription")}>Save</button>
"""
```

See **Selector contract** below for the resolver order.

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

1. **Pick the most stable selector that already exists.** The runtime
   tries `data-demo-id` first, then falls back to `document.querySelector`,
   so any of these work as targets:

       DemoDirector.click("save-prescription")          # data-demo-id
       DemoDirector.click("#save-prescription")         # element id
       DemoDirector.click("button[name=publish]")       # attribute selector

   Prefer existing handles that the host app *already* uses for its own
   purposes — semantic ids the sidebar nav links to, form-field ids
   labels point at — those are the ones the host has the strongest
   incentive to keep stable. Reach for `data-demo-id` (via the
   `demo_id/1` HEEx helper) when no such handle exists, or when the
   element you want to target has nothing distinctive about it (icon
   buttons, repeated rows). Either way, don't author against
   `:nth-child` chains or deep descendant paths — those break the
   moment a sibling moves.

2. **Pace generously.** Subtitles reveal word-by-word at ~110ms/word —
   the trailing `wait` should be at least the reveal duration plus a
   beat. `fill_typed` defaults to 35ms/char, which reads naturally; lower
   for filler text, higher for content the viewer is meant to read.
   For LiveView-driven inputs with `phx-debounce`, allow the debounce
   window plus a server roundtrip (~600–1200ms total) before reading
   the resulting DOM state.

Test by saving and opening `<mount>/demos`. The new entry shows up
automatically.

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

- **Open `<mount>`** in your browser (e.g.
  `http://localhost:4000/dev/demo-director`) to see every saved demo with
  a Play button. Clicking Play navigates the browser to the demo's
  `@start_at` and runs it. (`<mount>/demos` works too — same listing.)
- **Run `mix demo_director.play <name>`** from a second terminal. The task
  prints a clickable URL like
  `http://localhost:4000/dev/demo-director/demos/<name>/play`. Opening it
  stashes the demo in `sessionStorage`, redirects to `@start_at`, and the
  overlay there picks it up on load.

## Try the example app

The package ships with a minimal Phoenix LiveView blog app — a post
composer, a public reader view, and a comments section — wired up in
`dev.exs` so the package can be smoke-tested end-to-end against a real
running app without a separate Mix project.

```bash
mix deps.get
mix dev
```

Open <http://localhost:4000/dev/demo-director> and click Play on any of
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
| Igniter | `~> 0.6`, optional (only used by the install task) | 0.7.x, 0.8.x |

## Selector contract

The runtime resolves targets in two passes: first as `data-demo-id`,
then — if no match — as a raw CSS selector via
`document.querySelector`. So all of these work:

```elixir
DemoDirector.click("save-prescription")     # data-demo-id="save-prescription"
DemoDirector.click("#save-prescription")    # element id
DemoDirector.click(".btn-primary")          # class
DemoDirector.click("button[type=submit]")   # attribute
```

The package's recommendation is to pick the most stable handle that
already exists in the host's markup — semantic ids the host already
uses for in-page navigation or `<label for="">` are the strongest
candidates because the host has its own reasons to keep them stable.
Reach for `data-demo-id` (via the `demo_id/1` HEEx helper) when no
such handle exists, or for elements that would be hard to disambiguate
otherwise (icon buttons, repeated rows). Avoid `:nth-child` chains and
deep descendant paths — those break the moment a sibling moves.

`data-demo-id` lookup runs first, so if you tag an element specifically
for the demo, that tag wins over any unrelated CSS selector match.

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

## Security

The threat model is "trusted dev environment, untrusted everything
else." The URL surface (`<mount>/demos/<name>/play`, `<mount>/play`,
the demos listing) is small and tamper-resistant in well-understood
ways; the trust ultimately rests on filesystem and network boundaries
the host app already enforces.

- **URL surface tamper-resistance.** The `name` segment of
  `<mount>/demos/<name>/play` is matched against an enumerated list
  of `.exs` files in `priv/demos/` (or `dev/priv/demos/`). It is
  never concatenated into a filesystem path, so URL-encoded path
  traversal cannot read or evaluate files outside those directories.
- **`Code.eval_file` is the primary trust boundary.** Demos are
  Elixir scripts; loading one runs the script in the host app's
  BEAM (the script's `IO.puts` is what produces the JS). Anyone with
  write access to `priv/demos/*.exs` therefore has BEAM code
  execution on the dev server. Don't accept demo scripts from
  untrusted contributors without reading them first.
- **Helpers produce safe JS by convention, not by enforcement.** The
  six helpers (`subtitle/1`, `highlight/1`, `fill/2`, `fill_typed/3`,
  `click/1`, `wait/1`) emit a bounded vocabulary of
  `window.DemoDirector.*(...)` calls with JSON-encoded arguments. But
  the runtime ultimately `eval`s whatever string the script writes
  to stdout — a script that calls `IO.puts("evil()")` instead of the
  helpers will get its raw JS evaluated in the browser. A future
  release may move the runtime to a structured-command dispatch (no
  client-side `eval`); for now, the safety property is "stick to the
  helpers."
- **Playback POST is localhost-only.** `<mount>/play` (the endpoint
  `mix demo_director.play` broadcasts to) rejects non-loopback
  remote IPs. An attacker on a separate host cannot cause arbitrary
  JS to be evaluated by overlay subscribers.
- **`dev_routes` is what keeps the integration out of prod.** None
  of the routes above compile when the host app's
  `Application.compile_env(:my_app, :dev_routes)` resolves false at
  compile time. Keeping that flag off in every environment except
  development is the load-bearing operational discipline.

## Caveats

**Treat automated demos the same way you treat manual ones.** Demo
interactions (e.g. submitting a form) can write real records, send
real emails, and queue real jobs. The installer wires the package
behind the standard Phoenix `dev_routes` flag; keep that gate in
place in environments where data integrity and side effects matter.

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

**Overlay component renders empty even though the route exists.**
The overlay only renders when `Application.get_env(:demo_director,
:mount_path)` is set. The router macro registers it via an `@on_load`
callback baked into your router module, which fires on every module
load. If the env still ends up nil at runtime — usually because of an
unusual release-build or umbrella-app setup that strips beam metadata
— the safe escape hatch is to set the path explicitly:

```elixir
# config/dev.exs
config :demo_director, mount_path: "/dev/demo-director"
```

If you ever see this in vanilla `mix phx.server`, please open an issue
— the macro is supposed to make this Just Work, and the workaround
above shouldn't be necessary.

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
