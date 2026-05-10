# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2026-05-10

### Changed

- Install task's agent-instructions template (the content that gets
  dropped into AGENTS.md / CLAUDE.md) was still telling agents "Never
  invent a CSS selector" and describing `data-demo-id` as mandatory.
  The runtime has accepted raw CSS selectors as a fallback since
  0.1.2, so the contract was a version behind reality. Template now
  recommends picking the most stable handle that already exists in
  the host's markup — semantic ids, form-field ids that `<label
  for="">` points at, distinctive attributes — and to reach for
  `data-demo-id` only when no such handle exists. `:nth-child`
  chains and deep descendant paths are still called out as fragile.
  Existing installations keep their old AGENTS.md / CLAUDE.md
  content; rerun `mix igniter.install demo_director` to refresh.

### Documentation

- README's selector-contract section rewritten to match the template
  change above, plus a pacing note for LiveView-driven inputs with
  `phx-debounce` (callers should allow the debounce window plus a
  server roundtrip — ~600–1200ms total — before reading the
  resulting DOM state). Production-stripping section now describes
  the deferred sandboxed demo-session primitive inline rather than
  pointing at an internal MEMORY.md.

## [0.1.3] - 2026-05-10

### Documentation

- README's "Replay a saved demo" section pointed at the wrong URL —
  `/dev/director/demos` — which neither the install task nor the
  router macro's default produce. Updated to `/dev/demo-director`,
  matching the macro's `@default_path`. Same fix applied to the
  `mix demo_director.play` example URL.
- README now mentions that the listing page is reachable at the bare
  mount path (`<mount>`) in addition to `<mount>/demos` (added in
  0.1.2 but not surfaced in the docs).
- README's manual wire-up section for the router macro previously
  used `demo_director "/director"`, which conflicted with what the
  install task generates and produced confusing URLs. Aligned to
  `demo_director "/demo-director"` so the docs match the installer.

## [0.1.2] - 2026-05-10

### Added

- The install task now also adds the playback socket to your
  endpoint (after the existing `Phoenix.LiveView.Socket`
  declaration) and writes `config :demo_director, pubsub: <OtpApp>.PubSub`
  into `config/dev.exs`. The post-install notice shrinks from three
  manual steps to one (the overlay-component HEEx edit), which stays
  manual on purpose because root layouts aren't AST-editable.
  Both new edits are idempotent — the task searches for an existing
  `DemoDirector.PlaybackSocket` socket declaration / `:demo_director`
  config block before adding.
- Selector resolver in the runtime now falls back to
  `document.querySelector` when a string isn't found via
  `data-demo-id`. Lets demos target existing semantic ids
  (`#vitals`), classes (`.btn-primary`), or any other CSS selector
  the host app already has, without forcing ad-hoc `data-demo-id`
  annotations. `data-demo-id` lookup is still tried first, so the
  recommended idiom is unchanged.
- `fillTyped` now dispatches a synthetic `keyup` event per character
  alongside the existing `input` event. Hosts that listen via
  `phx-keyup` (rather than `phx-change`) now react to typed input
  during demo playback.
- Demos listing page is now reachable at the bare mount path (e.g.
  `/dev/demo-director`) in addition to the original `<mount>/demos`.
  Both URLs render the same listing.
- Listing-page styling switched to a purple palette (Elixir-ish
  lavender on deep purple). The Play button stays red for contrast.
  The demo overlay (subtitle bar, highlight ring) is intentionally
  unchanged — it stays neutral so it works visually on any host
  app's color scheme.

### Fixed

- `mix igniter.install demo_director` crashed with
  `FunctionClauseError in Rewrite.update!/2` while seeding `AGENTS.md`
  / `CLAUDE.md`. The install task's updater callback returned a raw
  string instead of the `Rewrite.Source` that
  `Igniter.create_or_update_file/4` expects from its 4th argument.
  Updates the source's `:content` via `Rewrite.Source.update/3`.
- The router edit was not idempotent: re-running the install task
  appended a duplicate `if Application.compile_env(:my_app, :dev_routes)`
  block on every run. The task now searches for an existing
  `import DemoDirector.Router` call before adding, mirroring the
  pattern used by the Tidewave installer.
- Subtitle bar's text was bidi-flipped on hosts with
  `<html dir="rtl">` — English content's punctuation could land on
  the wrong side. Subtitle node now carries `dir="auto"` so its
  visual direction is determined by the first strong character of
  the subtitle text itself, regardless of the host page's direction.

### Documentation

- README's "Add to your Phoenix app" section notes that
  `demo_director` assumes the host app has a working Phoenix
  LiveView setup; the installer does not bootstrap LiveView from
  scratch.
- The README's manual wire-up step for the overlay component now
  explains why that step stays manual (HEEx isn't AST-editable like
  Elixir, so editing root layouts programmatically would be
  string-level surgery on a frequently-customized file) and notes
  that the component is prod-safe to leave unconditionally inside
  `<body>` (it returns empty markup when no mount path is
  registered). The install task's post-install notice carries the
  same explanation in shorter form.

## [0.1.1] - 2026-05-10

### Changed

- Reworded package description / README tagline to lead with what the
  package does ("Narrated, highlighted, animated demos for Phoenix
  LiveView") before the workflow tagline.
- Added Hex.pm and HexDocs badges to the README.

## [0.1.0] - 2026-05-10

### Added

- Helper API: `subtitle/1`, `highlight/1`, `fill/2`, `fill_typed/3`,
  `click/1`, `wait/1`. Each emits a JS string the agent passes to
  `browser_eval` (or that gets saved into a `.exs` script).
- HEEx integration via `demo_id/1` for stable selectors through LiveView
  patches.
- Overlay component (`demo_director_overlay`) rendering a
  word-by-word-revealed subtitle bar and a target-tracking highlight ring.
- Router macro (`demo_director "/director"`) mounting:
  - static assets (CSS + JS) at `<mount>/demo_director.{css,js}`
  - a web demos browser at `<mount>/demos` listing every saved demo
  - a per-demo JSON endpoint at `<mount>/demos/<name>.js`
  - a playback POST endpoint at `<mount>/play` (localhost-only)
- Phoenix channel + socket (`DemoDirector.PlaybackSocket`) that
  relays demo JS broadcasts to every connected overlay.
- `mix demo_director.play <name>` task that POSTs a saved demo's JS
  to the running dev server. Reads `# @start_at "/path"` metadata from
  the demo file and navigates the browser there before running.
- Igniter-based install task (`mix igniter.install demo_director`)
  that wires the router macro and seeds AGENTS.md / CLAUDE.md with the
  agent contract.
