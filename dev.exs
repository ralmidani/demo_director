#######################################
# Development Server for demo_director
#
# Boots a small Phoenix LiveView blog app that mounts the
# demo_director overlay, so you can exercise the library against
# a real (in-memory) Phoenix surface.
#
# Usage:
#
#   $ iex -S mix dev
#
# Or just `mix dev`. The endpoint listens on http://127.0.0.1:4000.
#######################################
Logger.configure(level: :debug)

# ----- Endpoint config -------------------------------------------------------

Application.put_env(:demo_director, ExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  server: true,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "qojKRrHQzrO7eVjy7jpJA9kPYO7cPolYqH6Gdlp7mzg7/0VFrPFGmUtq23mxiDAk",
  render_errors: [
    formats: [html: ExampleWeb.ErrorHTML, json: ExampleWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Example.PubSub,
  live_view: [signing_salt: "e/AUR6yt"],
  live_reload: [
    web_console_logger: true,
    patterns: [~r/dev\.exs$/, ~r"dev/priv/static/.*"]
  ]
)

Application.put_env(:demo_director, :dev_routes, true)
Application.put_env(:demo_director, :pubsub, Example.PubSub)
Application.put_env(:phoenix, :json_library, Jason)
Application.put_env(:phoenix, :plug_init_mode, :runtime)

Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Application.put_env(:phoenix_live_view, :enable_expensive_runtime_checks, true)

# ----- Domain ---------------------------------------------------------------

defmodule Example.Post do
  @moduledoc "In-memory blog post with validation."
  defstruct [
    :id,
    :title,
    :slug,
    :meta_description,
    :body,
    :tags,
    :status,
    :inserted_at,
    :updated_at
  ]

  def validate(params) when is_map(params) do
    title = clean_string(params["title"])
    slug = clean_string(params["slug"])
    meta = clean_string(params["meta_description"])
    body = clean_string(params["body"])
    tags = clean_tags(params["tags"])
    status = parse_status(params["status"])

    errors =
      %{}
      |> validate_title(title)
      |> validate_slug(slug)
      |> validate_meta(meta, status)
      |> validate_body(body, status)
      |> validate_tags(tags, status)

    if map_size(errors) == 0 do
      now = DateTime.utc_now()

      {:ok,
       %__MODULE__{
         id: params["id"] || generate_id(),
         title: title,
         slug: slug,
         meta_description: meta,
         body: body,
         tags: tags,
         status: status,
         inserted_at: params["inserted_at"] || now,
         updated_at: now
       }}
    else
      {:error, errors}
    end
  end

  def checklist(params) when is_map(params) do
    title = clean_string(params["title"])
    slug = clean_string(params["slug"])
    meta = clean_string(params["meta_description"])
    body = clean_string(params["body"])
    tags = clean_tags(params["tags"])

    [
      {:title, "Title 5–100 characters", title_ok?(title)},
      {:slug, "URL-safe slug", slug_ok?(slug)},
      {:meta_description, "Meta description 50–160 characters", meta_ok?(meta)},
      {:body, "Body has at least 50 words", body_word_count(body) >= 50},
      {:tags, "At least one tag", tags != []}
    ]
  end

  def reading_time_minutes(body) do
    body
    |> body_word_count()
    |> Kernel./(200)
    |> Float.ceil()
    |> trunc()
    |> max(1)
  end

  def word_count(body), do: body_word_count(body)

  def slugify(nil), do: ""

  def slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp clean_string(nil), do: ""
  defp clean_string(s) when is_binary(s), do: String.trim(s)
  defp clean_string(_), do: ""

  defp clean_tags(nil), do: []

  defp clean_tags(s) when is_binary(s) do
    s
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp clean_tags(list) when is_list(list) do
    list
    |> Enum.map(&clean_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp parse_status("published"), do: :published
  defp parse_status(:published), do: :published
  defp parse_status(_), do: :draft

  defp validate_title(errors, title) do
    cond do
      title == "" -> add_error(errors, :title, "is required")
      String.length(title) < 5 -> add_error(errors, :title, "must be at least 5 characters")
      String.length(title) > 100 -> add_error(errors, :title, "must be at most 100 characters")
      true -> errors
    end
  end

  defp validate_slug(errors, slug) do
    cond do
      slug == "" -> add_error(errors, :slug, "is required")
      not slug_ok?(slug) -> add_error(errors, :slug, "must be lowercase letters, numbers, and dashes")
      true -> errors
    end
  end

  defp validate_meta(errors, _meta, :draft), do: errors

  defp validate_meta(errors, meta, _status) do
    cond do
      meta == "" -> add_error(errors, :meta_description, "is required to publish")
      String.length(meta) < 50 -> add_error(errors, :meta_description, "must be at least 50 characters")
      String.length(meta) > 160 -> add_error(errors, :meta_description, "must be at most 160 characters")
      true -> errors
    end
  end

  defp validate_body(errors, _body, :draft), do: errors

  defp validate_body(errors, body, _status) do
    cond do
      body == "" -> add_error(errors, :body, "is required to publish")
      body_word_count(body) < 50 -> add_error(errors, :body, "must have at least 50 words to publish")
      true -> errors
    end
  end

  defp validate_tags(errors, [], :published),
    do: add_error(errors, :tags, "must have at least one tag to publish")

  defp validate_tags(errors, _tags, _status), do: errors

  defp title_ok?(title), do: String.length(title) >= 5 and String.length(title) <= 100
  defp slug_ok?(slug), do: slug != "" and Regex.match?(~r/^[a-z0-9]+(-[a-z0-9]+)*$/, slug)
  defp meta_ok?(meta), do: String.length(meta) >= 50 and String.length(meta) <= 160

  defp body_word_count(nil), do: 0

  defp body_word_count(body) when is_binary(body) do
    body
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp add_error(errors, field, msg), do: Map.update(errors, field, [msg], &[msg | &1])

  defp generate_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 12)
  end
end

defmodule Example.Comment do
  @moduledoc "In-memory comment on a post."
  defstruct [:id, :post_id, :author_name, :author_email, :body, :inserted_at]

  def validate(post_id, params) when is_binary(post_id) and is_map(params) do
    name = clean(params["author_name"])
    email = clean(params["author_email"])
    body = clean(params["body"])

    errors =
      %{}
      |> validate_name(name)
      |> validate_body(body)
      |> validate_email(email)

    if map_size(errors) == 0 do
      {:ok,
       %__MODULE__{
         id: generate_id(),
         post_id: post_id,
         author_name: name,
         author_email: empty_to_nil(email),
         body: body,
         inserted_at: DateTime.utc_now()
       }}
    else
      {:error, errors}
    end
  end

  defp clean(nil), do: ""
  defp clean(s) when is_binary(s), do: String.trim(s)
  defp clean(_), do: ""

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(s), do: s

  defp validate_name(errors, name) do
    cond do
      name == "" -> add_error(errors, :author_name, "is required")
      String.length(name) < 2 -> add_error(errors, :author_name, "must be at least 2 characters")
      String.length(name) > 50 -> add_error(errors, :author_name, "must be at most 50 characters")
      true -> errors
    end
  end

  defp validate_body(errors, body) do
    cond do
      body == "" -> add_error(errors, :body, "is required")
      String.length(body) < 5 -> add_error(errors, :body, "must be at least 5 characters")
      String.length(body) > 1_000 -> add_error(errors, :body, "must be at most 1,000 characters")
      true -> errors
    end
  end

  defp validate_email(errors, ""), do: errors

  defp validate_email(errors, email) do
    if Regex.match?(~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/, email) do
      errors
    else
      add_error(errors, :author_email, "is not a valid email")
    end
  end

  defp add_error(errors, field, msg), do: Map.update(errors, field, [msg], &[msg | &1])

  defp generate_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 12)
  end
end

defmodule Example.Store do
  @moduledoc """
  In-memory backing store for posts and comments.
  Comment writes broadcast on `posts:<post_id>` over Example.PubSub.
  """
  use Agent

  alias Example.{Comment, Post}

  @pubsub Example.PubSub

  def start_link(_opts) do
    Agent.start_link(fn -> seed() end, name: __MODULE__)
  end

  def list_posts do
    Agent.get(__MODULE__, fn state ->
      state.posts
      |> Map.values()
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
    end)
  end

  def search_posts(""), do: list_posts()

  def search_posts(query) when is_binary(query) do
    needle = String.downcase(query)

    list_posts()
    |> Enum.filter(fn post ->
      String.contains?(String.downcase(post.title), needle) or
        Enum.any?(post.tags, &String.contains?(String.downcase(&1), needle))
    end)
  end

  def get_post(id) do
    Agent.get(__MODULE__, fn state -> Map.get(state.posts, id) end)
  end

  def get_post_by_slug(slug) do
    Agent.get(__MODULE__, fn state ->
      state.posts
      |> Map.values()
      |> Enum.find(&(&1.slug == slug))
    end)
  end

  def put_post(%Post{id: id} = post) do
    Agent.update(__MODULE__, fn state -> put_in(state.posts[id], post) end)
    post
  end

  def delete_post(id) do
    Agent.update(__MODULE__, fn state ->
      state
      |> update_in([:posts], &Map.delete(&1, id))
      |> update_in([:comments], &Map.delete(&1, id))
    end)
  end

  def list_comments(post_id) do
    Agent.get(__MODULE__, fn state ->
      state.comments
      |> Map.get(post_id, [])
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    end)
  end

  def count_comments(post_id) do
    Agent.get(__MODULE__, fn state ->
      state.comments
      |> Map.get(post_id, [])
      |> length()
    end)
  end

  def put_comment(%Comment{post_id: post_id} = comment) do
    Agent.update(__MODULE__, fn state ->
      update_in(state.comments[post_id], fn list -> [comment | list || []] end)
    end)

    Phoenix.PubSub.broadcast(@pubsub, "posts:#{post_id}", {:new_comment, comment})
    comment
  end

  def subscribe_to_post(post_id) do
    Phoenix.PubSub.subscribe(@pubsub, "posts:#{post_id}")
  end

  defp seed do
    {:ok, p1} =
      Post.validate(%{
        "id" => "welcome-post",
        "title" => "Welcome to the example blog",
        "slug" => "welcome",
        "meta_description" =>
          "A short tour of the composer, with a live SEO preview, validation guardrails, and a reading-time estimate.",
        "body" => """
        This is a small demo of a blog composer built on Phoenix LiveView. As you
        write, a search-result preview updates beside the editor, a guardrail bar
        tracks the five publish requirements at a glance, and the footer estimates
        how long the post will take a typical reader to finish.

        The killer features here are: a live SEO snippet preview that mirrors a
        Google result card, a reading-time estimator that updates per keystroke,
        and a markdown-to-HTML preview pane that renders alongside your draft.

        Posts and comments live in an in-memory Agent. Restart the server and they
        reset cleanly. That is genuinely all you need to know — try the **New post**
        button to see the composer in action, or open this post to leave a comment.
        Comments stream in over Phoenix.PubSub, so multiple readers see new posts
        without refreshing.
        """,
        "tags" => "demo, walkthrough, liveview",
        "status" => "published"
      })

    {:ok, p2} =
      Post.validate(%{
        "id" => "draft-post",
        "title" => "Half-written draft",
        "slug" => "half-written-draft",
        "meta_description" => "",
        "body" =>
          "Some words but not yet enough to publish. The guardrail bar will tell you what's still missing.",
        "tags" => "draft",
        "status" => "draft"
      })

    %{
      posts: %{p1.id => p1, p2.id => p2},
      comments: %{
        p1.id => [
          %Example.Comment{
            id: "seed-comment-1",
            post_id: p1.id,
            author_name: "Riya",
            author_email: nil,
            body: "Loving the SEO preview. Watching the slug derive itself is satisfying.",
            inserted_at: DateTime.add(DateTime.utc_now(), -7200, :second)
          }
        ]
      }
    }
  end
end

# ----- Web layer ------------------------------------------------------------

defmodule ExampleWeb do
  @moduledoc false

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      alias Phoenix.LiveView.JS
      alias ExampleWeb.Layouts
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ExampleWeb.Endpoint,
        router: ExampleWeb.Router,
        statics: ExampleWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule ExampleWeb.Layouts do
  @moduledoc false
  use ExampleWeb, :html

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <.live_title default="Example" suffix=" · demo_director dev">
          {assigns[:page_title]}
        </.live_title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/phoenix.js"}>
        </script>
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/phoenix_html.js"}>
        </script>
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/phoenix_live_view.js"}>
        </script>
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
        </script>
      </head>
      <body>
        {@inner_content}
        <DemoDirector.Components.demo_director_overlay />
      </body>
    </html>
    """
  end

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    """
  end
end

# ----- LiveViews ------------------------------------------------------------

defmodule ExampleWeb.PostsLive.Index do
  use ExampleWeb, :live_view

  import DemoDirector.HEEx

  alias Example.{Post, Store}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Posts")
     |> assign(:query, "")
     |> assign_posts("")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["q"] || ""
    {:noreply, socket |> assign(:query, query) |> assign_posts(query)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/?#{%{q: query}}", replace: true)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Store.delete_post(id)
    {:noreply, socket |> put_flash(:info, "Post deleted") |> assign_posts(socket.assigns.query)}
  end

  defp assign_posts(socket, query) do
    posts = Store.search_posts(query)
    assign(socket, :posts, posts)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="page">
      <header class="page__header">
        <h1>Posts</h1>
        <.link patch={~p"/posts/new"} class="btn btn--primary" {demo_id("new-post-button")}>
          New post
        </.link>
      </header>

      <form phx-change="search" phx-submit="search" class="search">
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Search by title or tag…"
          autocomplete="off"
          phx-debounce="120"
          {demo_id("posts-search-input")}
        />
      </form>

      <%= if @posts == [] do %>
        <div class="empty">
          <%= if @query == "" do %>
            No posts yet. <.link patch={~p"/posts/new"}>Write your first one</.link>.
          <% else %>
            No posts match <strong>{@query}</strong>.
          <% end %>
        </div>
      <% else %>
        <ul class="post-list" {demo_id("posts-list")}>
          <li :for={post <- @posts} class="post-row" {demo_id("post-row-#{post.id}")}>
            <div class="post-row__main">
              <.link
                navigate={post_link(post)}
                class="post-row__title"
                {demo_id("post-link-#{post.id}")}
              >
                {post.title}
              </.link>
              <p class="post-row__meta">
                <span class={"badge badge--#{post.status}"}>{post.status}</span>
                <span>·</span>
                <span>{Post.reading_time_minutes(post.body)} min read</span>
                <span>·</span>
                <span>{Store.count_comments(post.id)} comments</span>
                <%= if post.tags != [] do %>
                  <span>·</span>
                  <span class="tags">
                    <span :for={tag <- post.tags} class="tag">{tag}</span>
                  </span>
                <% end %>
              </p>
            </div>
            <div class="post-row__actions">
              <.link
                patch={~p"/posts/#{post.id}/edit"}
                class="btn btn--ghost"
                {demo_id("edit-post-#{post.id}")}
              >
                Edit
              </.link>
              <button
                type="button"
                phx-click="delete"
                phx-value-id={post.id}
                data-confirm="Delete this post?"
                class="btn btn--ghost btn--danger"
                {demo_id("delete-post-#{post.id}")}
              >
                Delete
              </button>
            </div>
          </li>
        </ul>
      <% end %>
    </main>
    """
  end

  defp post_link(%Post{status: :published, slug: slug}), do: ~p"/posts/#{slug}"
  defp post_link(%Post{id: id}), do: ~p"/posts/#{id}/edit"
end

defmodule ExampleWeb.PostsLive.Show do
  use ExampleWeb, :live_view

  import DemoDirector.HEEx

  alias Example.{Comment, Post, Store}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Store.get_post_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Post not found")
         |> push_navigate(to: ~p"/")}

      %Post{status: :published} = post ->
        if connected?(socket), do: Store.subscribe_to_post(post.id)
        comments = Store.list_comments(post.id)

        {:ok,
         socket
         |> assign(:page_title, post.title)
         |> assign(:post, post)
         |> assign(:rendered_body, render_markdown(post.body))
         |> stream(:comments, comments)
         |> assign(:comment_count, length(comments))
         |> reset_comment_form()}

      %Post{} ->
        {:ok,
         socket
         |> put_flash(:error, "That post is still a draft")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate_comment", %{"comment" => params}, socket) do
    {:noreply, assign(socket, :comment_params, params)}
  end

  def handle_event("submit_comment", %{"comment" => params}, socket) do
    case Comment.validate(socket.assigns.post.id, params) do
      {:ok, comment} ->
        Store.put_comment(comment)
        {:noreply, socket |> reset_comment_form() |> put_flash(:info, "Comment posted")}

      {:error, errors} ->
        {:noreply, socket |> assign(:comment_params, params) |> assign(:comment_errors, errors)}
    end
  end

  @impl true
  def handle_info({:new_comment, %Comment{} = comment}, socket) do
    {:noreply,
     socket
     |> stream_insert(:comments, comment, at: 0)
     |> assign(:comment_count, socket.assigns.comment_count + 1)}
  end

  defp reset_comment_form(socket) do
    socket
    |> assign(:comment_params, %{
      "author_name" => "",
      "author_email" => "",
      "body" => ""
    })
    |> assign(:comment_errors, %{})
  end

  defp render_markdown(body) do
    case Earmark.as_html(body, escape: true, smartypants: false) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
      _ -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="page page--reader">
      <header class="page__header">
        <.link navigate={~p"/"} class="btn btn--ghost" {demo_id("reader-back-link")}>
          ← All posts
        </.link>
      </header>

      <article class="post">
        <header class="post__header">
          <h1 {demo_id("post-title")}>{@post.title}</h1>
          <p class="post__meta">
            {Post.reading_time_minutes(@post.body)} min read
            <%= if @post.tags != [] do %>
              · <span :for={tag <- @post.tags} class="tag">{tag}</span>
            <% end %>
          </p>
        </header>
        <div class="post__body" {demo_id("post-body")}>
          {Phoenix.HTML.raw(@rendered_body)}
        </div>
      </article>

      <section class="comments" {demo_id("comments-section")}>
        <h2>{@comment_count} comments</h2>

        <form
          phx-change="validate_comment"
          phx-submit="submit_comment"
          class="comment-form"
          {demo_id("comment-form")}
        >
          <label class="field">
            <span class="field__label">Name</span>
            <input
              type="text"
              name="comment[author_name]"
              value={@comment_params["author_name"]}
              {demo_id("comment-name-input")}
            />
            <.error_for errors={@comment_errors} field={:author_name} />
          </label>

          <label class="field">
            <span class="field__label">Email <span class="field__hint">(optional)</span></span>
            <input
              type="email"
              name="comment[author_email]"
              value={@comment_params["author_email"]}
              {demo_id("comment-email-input")}
            />
            <.error_for errors={@comment_errors} field={:author_email} />
          </label>

          <label class="field">
            <span class="field__label">Comment</span>
            <textarea
              name="comment[body]"
              rows="3"
              {demo_id("comment-body-input")}
            >{@comment_params["body"]}</textarea>
            <.error_for errors={@comment_errors} field={:body} />
          </label>

          <button type="submit" class="btn btn--primary" {demo_id("comment-submit-button")}>
            Post comment
          </button>
        </form>

        <ul class="comment-list" id="comments" phx-update="stream" {demo_id("comments-list")}>
          <li :for={{dom_id, c} <- @streams.comments} id={dom_id} class="comment">
            <header class="comment__header">
              <strong>{c.author_name}</strong>
              <time>{relative_time(c.inserted_at)}</time>
            </header>
            <p class="comment__body">{c.body}</p>
          </li>
        </ul>
      </section>
    </main>
    """
  end

  defp relative_time(%DateTime{} = dt) do
    seconds = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86_400 -> "#{div(seconds, 3600)} h ago"
      true -> "#{div(seconds, 86_400)} d ago"
    end
  end

  attr :errors, :map, required: true
  attr :field, :atom, required: true

  defp error_for(assigns) do
    ~H"""
    <%= if msgs = Map.get(@errors, @field) do %>
      <span class="field__error">{Enum.join(msgs, " · ")}</span>
    <% end %>
    """
  end
end

defmodule ExampleWeb.PostsLive.Form do
  use ExampleWeb, :live_view

  import DemoDirector.HEEx

  alias Example.{Post, Store}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case apply_action(socket, socket.assigns.live_action, params) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  defp apply_action(socket, :new, _params) do
    params = blank_params()
    {:ok, assign_form(socket, params, :new, "New post")}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Store.get_post(id) do
      nil ->
        {:error, socket |> put_flash(:error, "Post not found") |> push_navigate(to: ~p"/")}

      %Post{} = post ->
        {:ok, assign_form(socket, post_to_params(post), :edit, "Editing: #{post.title}", post)}
    end
  end

  defp assign_form(socket, params, action, page_title, post \\ nil) do
    socket
    |> assign(:page_title, page_title)
    |> assign(:action, action)
    |> assign(:post, post)
    |> assign(:params, params)
    |> assign_derived(params)
  end

  @impl true
  def handle_event("validate", %{"post" => raw}, socket) do
    raw = Map.merge(raw, %{"slug" => slug_value(socket.assigns.params, raw)})
    {:noreply, socket |> assign(:params, raw) |> assign_derived(raw)}
  end

  def handle_event("save", %{"post" => raw, "intent" => intent}, socket) do
    raw = Map.put(raw, "status", if(intent == "publish", do: "published", else: "draft"))
    raw = with_id(raw, socket.assigns.post)

    case Post.validate(raw) do
      {:ok, post} ->
        Store.put_post(post)

        socket =
          socket
          |> put_flash(:info, flash_for(intent))
          |> push_navigate(to: redirect_target(post, intent))

        {:noreply, socket}

      {:error, _errors} ->
        {:noreply,
         socket
         |> assign(:params, raw)
         |> assign(:save_attempted?, true)
         |> assign_derived(raw)}
    end
  end

  defp assign_derived(socket, params) do
    checklist = Post.checklist(params)
    word_count = Post.word_count(params["body"])
    reading_time = Post.reading_time_minutes(params["body"])

    {ok?, errors} =
      case Post.validate(Map.put(params, "status", "published")) do
        {:ok, _post} -> {true, %{}}
        {:error, errs} -> {false, errs}
      end

    visible_errors = if Map.get(socket.assigns, :save_attempted?, false), do: errors, else: %{}

    socket
    |> assign(:checklist, checklist)
    |> assign(:word_count, word_count)
    |> assign(:reading_time, reading_time)
    |> assign(:can_publish?, ok?)
    |> assign(:errors, visible_errors)
    |> assign(:rendered_body, render_markdown(params["body"]))
  end

  defp slug_value(prev_params, new_raw) do
    new_slug = Map.get(new_raw, "slug", "")
    new_title = Map.get(new_raw, "title", "")
    prev_title = prev_params["title"] || ""
    prev_slug = prev_params["slug"] || ""

    cond do
      new_slug != "" and new_slug != prev_slug -> new_slug
      prev_slug == Post.slugify(prev_title) -> Post.slugify(new_title)
      true -> new_slug
    end
  end

  defp post_to_params(%Post{} = post) do
    %{
      "id" => post.id,
      "title" => post.title,
      "slug" => post.slug,
      "meta_description" => post.meta_description,
      "body" => post.body,
      "tags" => Enum.join(post.tags, ", "),
      "status" => to_string(post.status)
    }
  end

  defp blank_params do
    %{
      "title" => "",
      "slug" => "",
      "meta_description" => "",
      "body" => "",
      "tags" => "",
      "status" => "draft"
    }
  end

  defp with_id(raw, %Post{id: id}), do: Map.put(raw, "id", id)
  defp with_id(raw, _), do: raw

  defp flash_for("publish"), do: "Post published"
  defp flash_for("save"), do: "Draft saved"
  defp flash_for(_), do: "Saved"

  defp redirect_target(%Post{status: :published, slug: slug}, "publish"), do: ~p"/posts/#{slug}"
  defp redirect_target(_post, _intent), do: ~p"/"

  defp render_markdown(nil), do: ""
  defp render_markdown(""), do: ""

  defp render_markdown(body) do
    case Earmark.as_html(body, escape: true, smartypants: false) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
      _ -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="page page--composer">
      <header class="page__header">
        <.link navigate={~p"/"} class="btn btn--ghost" {demo_id("composer-back-link")}>
          ← Back
        </.link>
        <h1>{@page_title}</h1>
      </header>

      <.guardrail_bar checklist={@checklist} can_publish?={@can_publish?} />

      <form
        phx-change="validate"
        phx-submit="save"
        class="composer"
        {demo_id("composer-form")}
      >
        <input type="hidden" name="intent" value="save" id="composer-intent" />

        <div class="composer__grid">
          <section class="composer__editor">
            <label class="field">
              <span class="field__label">Title</span>
              <input
                type="text"
                name="post[title]"
                value={@params["title"]}
                phx-debounce="80"
                {demo_id("post-title-input")}
              />
              <.error_for errors={@errors} field={:title} />
            </label>

            <label class="field">
              <span class="field__label">Slug</span>
              <div class="field__slug">
                <span class="field__prefix">/posts/</span>
                <input
                  type="text"
                  name="post[slug]"
                  value={@params["slug"]}
                  phx-debounce="120"
                  {demo_id("post-slug-input")}
                />
              </div>
              <.error_for errors={@errors} field={:slug} />
            </label>

            <label class="field">
              <span class="field__label">
                Meta description
                <span class="field__count">
                  {String.length(@params["meta_description"] || "")}/160
                </span>
              </span>
              <textarea
                name="post[meta_description]"
                rows="2"
                phx-debounce="120"
                {demo_id("post-meta-input")}
              >{@params["meta_description"]}</textarea>
              <.error_for errors={@errors} field={:meta_description} />
            </label>

            <label class="field">
              <span class="field__label">
                Body
                <span class="field__count">
                  {@word_count} words · {@reading_time} min read
                </span>
              </span>
              <textarea
                name="post[body]"
                rows="14"
                phx-debounce="160"
                {demo_id("post-body-input")}
              >{@params["body"]}</textarea>
              <.error_for errors={@errors} field={:body} />
            </label>

            <label class="field">
              <span class="field__label">Tags <span class="field__hint">(comma-separated)</span></span>
              <input
                type="text"
                name="post[tags]"
                value={@params["tags"]}
                phx-debounce="120"
                {demo_id("post-tags-input")}
              />
              <.error_for errors={@errors} field={:tags} />
            </label>
          </section>

          <aside class="composer__preview">
            <.seo_preview
              title={@params["title"]}
              slug={@params["slug"]}
              meta={@params["meta_description"]}
            />

            <section class="md-preview">
              <h2 class="composer__section-title">Live preview</h2>
              <article class="md-preview__body" {demo_id("post-body-preview")}>
                {Phoenix.HTML.raw(@rendered_body)}
              </article>
            </section>
          </aside>
        </div>

        <footer class="composer__actions">
          <button
            type="submit"
            class="btn btn--ghost"
            phx-click={JS.set_attribute({"value", "save"}, to: "#composer-intent")}
            {demo_id("save-draft-button")}
          >
            Save draft
          </button>
          <button
            type="submit"
            class="btn btn--primary"
            disabled={!@can_publish?}
            phx-click={JS.set_attribute({"value", "publish"}, to: "#composer-intent")}
            {demo_id("publish-button")}
          >
            Publish
          </button>
        </footer>
      </form>
    </main>
    """
  end

  attr :checklist, :list, required: true
  attr :can_publish?, :boolean, required: true

  defp guardrail_bar(assigns) do
    ~H"""
    <section class="guardrail" aria-label="Publish checklist" {demo_id("guardrail-bar")}>
      <div class="guardrail__items">
        <span
          :for={{key, label, ok?} <- @checklist}
          class={["guardrail__item", ok? && "guardrail__item--ok"]}
          {demo_id("guardrail-#{key}")}
        >
          <span class="guardrail__check" aria-hidden="true">
            {if ok?, do: "✓", else: "•"}
          </span>
          {label}
        </span>
      </div>
      <div class="guardrail__status">
        {if @can_publish?, do: "Ready to publish", else: "Not yet ready"}
      </div>
    </section>
    """
  end

  attr :title, :string, default: ""
  attr :slug, :string, default: ""
  attr :meta, :string, default: ""

  defp seo_preview(assigns) do
    assigns =
      assigns
      |> assign(:display_title, truncate(assigns.title || "Untitled post", 60))
      |> assign(:display_url, "https://example.com/posts/#{assigns.slug || "your-post-slug"}")
      |> assign(
        :display_meta,
        truncate(
          assigns.meta || "Your meta description previews here as you write it.",
          155
        )
      )

    ~H"""
    <section class="seo-preview" aria-label="Search-result preview" {demo_id("seo-preview")}>
      <h2 class="composer__section-title">Search-result preview</h2>
      <div class="seo-preview__card">
        <div class="seo-preview__title">{@display_title}</div>
        <div class="seo-preview__url">{@display_url}</div>
        <div class="seo-preview__meta">{@display_meta}</div>
      </div>
    </section>
    """
  end

  defp truncate(string, max) when is_binary(string) do
    if String.length(string) > max do
      String.slice(string, 0, max - 1) <> "…"
    else
      string
    end
  end

  defp truncate(_, _), do: ""

  attr :errors, :map, required: true
  attr :field, :atom, required: true

  defp error_for(assigns) do
    ~H"""
    <%= if msgs = Map.get(@errors, @field) do %>
      <span class="field__error">{Enum.join(msgs, " · ")}</span>
    <% end %>
    """
  end
end

# ----- Error renderers -------------------------------------------------------

defmodule ExampleWeb.ErrorHTML do
  @moduledoc false
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule ExampleWeb.ErrorJSON do
  @moduledoc false
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

# ----- Router ---------------------------------------------------------------

defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    live "/", PostsLive.Index, :index
    live "/posts/new", PostsLive.Form, :new
    live "/posts/:id/edit", PostsLive.Form, :edit
    live "/posts/:slug", PostsLive.Show, :show
  end

  if Application.compile_env(:demo_director, :dev_routes) do
    import DemoDirector.Router

    scope "/dev" do
      demo_director "/director"
    end
  end
end

# ----- Endpoint -------------------------------------------------------------

defmodule ExampleWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :demo_director

  @session_options [
    store: :cookie,
    key: "_example_key",
    signing_salt: "fyLd9gtW",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  socket "/director/socket", DemoDirector.PlaybackSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: Path.expand("dev/priv/static", File.cwd!()),
    gzip: not code_reloading?,
    only: ExampleWeb.static_paths()

  if Mix.env() == :dev do
    plug Tidewave
  end

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ExampleWeb.Router
end

# ----- Boot supervision tree ------------------------------------------------

children = [
  {Phoenix.PubSub, name: Example.PubSub},
  Example.Store,
  ExampleWeb.Endpoint
]

{:ok, _} = Supervisor.start_link(children, strategy: :one_for_one, name: Example.Supervisor)

Process.sleep(:infinity)
