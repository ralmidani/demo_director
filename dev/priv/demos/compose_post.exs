# Demo: compose a post from scratch.
# @start_at "/"
#
# Walks through every guardrail check in order:
#   1. Type a title → SEO preview animates
#   2. Slug auto-derives → guardrail tick
#   3. Type meta description → guardrail tick
#   4. Type body → reading-time updates → guardrail tick
#   5. Add tags → guardrail tick
#   6. Click Publish → land on the public reader view

alias DemoDirector, as: TD

steps = [
  TD.subtitle("Let's compose a new post from scratch."),
  TD.wait(2000),

  TD.subtitle("First we'll head to the composer."),
  TD.wait(1400),
  TD.highlight("new-post-button"),
  TD.wait(900),
  TD.click("new-post-button"),
  TD.wait(1300),

  TD.subtitle("The guardrail bar shows what's needed to publish."),
  TD.highlight("guardrail-bar"),
  TD.wait(2600),

  TD.subtitle("Now the title — watch the search-result preview update as we type."),
  TD.wait(2000),
  TD.highlight("post-title-input"),
  TD.wait(700),
  TD.fill_typed("post-title-input", "Building deterministic demos with Tidewave"),
  TD.wait(1500),

  TD.subtitle("The slug derives automatically. Notice the guardrail bar."),
  TD.highlight("post-slug-input"),
  TD.wait(2400),

  TD.subtitle("Meta description — Google previews up to about 155 characters."),
  TD.wait(1800),
  TD.highlight("post-meta-input"),
  TD.wait(700),
  TD.fill_typed(
    "post-meta-input",
    "An end-to-end walkthrough of authoring AI-driven product demos for Phoenix LiveView using DemoDirector — author with Tidewave, play back in your LiveView app."
  ),
  TD.wait(1700),

  TD.subtitle("Now the body. Reading time updates per keystroke."),
  TD.wait(1700),
  TD.highlight("post-body-input"),
  TD.wait(700),
  TD.fill_typed(
    "post-body-input",
    "## Why determinism matters\n\nAI agents are great at improvising the first run of a demo, but they drift on the second and the third. DemoDirector keeps the action sequence in a saved script, so the demo plays back the same way every time — for sales calls, for onboarding, for screencasts.\n\nThe overlay layer is small: a subtitle bar, a highlight ring, and slowed typing animation. Selectors stay stable through `data-demo-id` attributes you sprinkle on the elements you want to direct.\n\nAuthor with Tidewave's `browser_eval` tab; play back from `<mount>/demos`, `mix demo_director.play <name>`, or any tool that can POST a script to the playback endpoint.",
    per_char_ms: 18
  ),
  TD.wait(1700),

  TD.subtitle("And finally, tags — for searchability."),
  TD.wait(1500),
  TD.highlight("post-tags-input"),
  TD.wait(700),
  TD.fill_typed("post-tags-input", "demo, liveview, tidewave"),
  TD.wait(1500),

  TD.subtitle("Every check is green. We can publish."),
  TD.highlight("guardrail-bar"),
  TD.wait(2200),

  TD.highlight("publish-button"),
  TD.wait(1000),
  TD.click("publish-button"),
  TD.wait(1500),

  TD.subtitle("And there's the post on the public reader view."),
  TD.highlight(nil),
  TD.wait(2400),

  TD.subtitle(nil)
]

IO.puts(Enum.join(steps, "\n"))
