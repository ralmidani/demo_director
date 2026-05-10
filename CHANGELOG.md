# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
