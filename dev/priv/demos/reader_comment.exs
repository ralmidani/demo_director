# Demo: a reader leaves a comment.
# @start_at "/"
#
# Highlights the PubSub-streaming comment list — when this script runs,
# the new comment broadcasts to every other open reader tab via
# Phoenix.PubSub on `posts:<post_id>`. The director here drives one
# tab; observers in others see the comment appear without a refresh.

alias DemoDirector, as: TD

steps = [
  TD.subtitle("Let's open the welcome post and leave a comment."),
  TD.wait(1500),

  TD.highlight("post-link-welcome-post"),
  TD.wait(900),
  TD.click("post-link-welcome-post"),
  TD.wait(1500),

  TD.subtitle("The comment form. Required name, optional email, body 5+ characters."),
  TD.highlight("comment-form"),
  TD.wait(2000),

  TD.fill_typed("comment-name-input", "Mei Tanaka"),
  TD.wait(800),

  TD.fill_typed("comment-body-input", "Loved the SEO preview. The way the slug auto-derived from the title felt magical."),
  TD.wait(1200),

  TD.highlight("comment-submit-button"),
  TD.wait(700),
  TD.click("comment-submit-button"),
  TD.wait(1500),

  TD.subtitle("New comment streamed in over Phoenix.PubSub. Other reader tabs see it too."),
  TD.highlight("comments-list"),
  TD.wait(2500),

  TD.subtitle(nil),
  TD.highlight(nil)
]

IO.puts(Enum.join(steps, "\n"))
