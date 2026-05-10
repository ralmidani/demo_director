# Demo: fix a half-written draft.
# @start_at "/"
#
# Starts on the index, opens the seeded "Half-written draft" post,
# then walks the guardrail bar from red to green.

alias DemoDirector, as: TD

steps = [
  TD.subtitle("This draft is half-written. Let's see what's missing."),
  TD.wait(1500),

  TD.highlight("edit-post-draft-post"),
  TD.wait(900),
  TD.click("edit-post-draft-post"),
  TD.wait(1200),

  TD.subtitle("The guardrail bar tells us exactly what to fix."),
  TD.highlight("guardrail-bar"),
  TD.wait(2500),

  TD.subtitle("First — the meta description is missing."),
  TD.highlight("guardrail-meta_description"),
  TD.wait(1500),
  TD.highlight("post-meta-input"),
  TD.wait(700),
  TD.fill_typed(
    "post-meta-input",
    "A short note on the half-finished thoughts that didn't quite become a finished post — until now."
  ),
  TD.wait(1500),

  TD.subtitle("Now the body — fewer than fifty words."),
  TD.highlight("guardrail-body"),
  TD.wait(1500),
  TD.highlight("post-body-input"),
  TD.wait(700),
  TD.fill_typed(
    "post-body-input",
    "\n\nWhat I had wanted to say is this: a guardrail bar is not a nag bar. It's a checklist that earns its place by quietly turning green as you do the work the publisher needs you to do. Each check is a thing the world agreed on long ago — a useful title, a meta description, enough body to read, a tag to find it later. The bar just makes those agreements visible.\n\nThat's the whole post. Hit publish.",
    per_char_ms: 14
  ),
  TD.wait(1500),

  TD.subtitle("Two left — the meta needs to be longer than fifty chars, and we need a tag."),
  TD.highlight("guardrail-tags"),
  TD.wait(1500),
  TD.highlight("post-tags-input"),
  TD.wait(700),
  TD.fill_typed("post-tags-input", "writing"),
  TD.wait(900),

  TD.subtitle("Bar's all green. Publish."),
  TD.highlight("publish-button"),
  TD.wait(900),
  TD.click("publish-button"),
  TD.wait(1500),

  TD.subtitle("Done."),
  TD.highlight(nil),
  TD.wait(2000),
  TD.subtitle(nil)
]

IO.puts(Enum.join(steps, "\n"))
