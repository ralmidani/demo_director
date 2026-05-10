# Demo: live search across posts.
# @start_at "/"
#
# Shows fill_typed against an input wired to phx-change, demonstrating
# how typing each character produces a real server round-trip and the
# list filters in real time.

alias DemoDirector, as: TD

steps = [
  TD.subtitle("The search box filters posts as you type."),
  TD.wait(1500),

  TD.highlight("posts-search-input"),
  TD.wait(900),
  TD.fill_typed("posts-search-input", "demo", per_char_ms: 80),
  TD.wait(1500),

  TD.subtitle("Each keystroke fired a phx-change event. The list re-rendered each time."),
  TD.wait(2200),

  TD.fill("posts-search-input", ""),
  TD.wait(800),
  TD.subtitle("Clearing the search returns the full list."),
  TD.wait(1500),

  TD.subtitle(nil),
  TD.highlight(nil)
]

IO.puts(Enum.join(steps, "\n"))
