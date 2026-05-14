defmodule DemoDirector.Plug.Index do
  @moduledoc """
  Renders a tiny HTML listing of every saved demo and serves each
  demo's emitted JS at `<mount>/demos/<name>.js`.

  Mounted by `DemoDirector.Router.demo_director/1` via
  `DemoDirector.Plug.Static`'s dispatch — `/demos` lists, and
  `/demos/<name>.js` returns the captured JS plus the demo's
  `start_at` route as a JSON wrapper.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: path} = conn, _opts) when path in [[], ["demos"]] do
    html = render_index(DemoDirector.Demos.list(), mount_path())

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def call(%Plug.Conn{path_info: ["demos", filename]} = conn, _opts) do
    case String.split(filename, ".") do
      [name, "js"] -> serve_demo_js(conn, name)
      _ -> not_found(conn)
    end
  end

  def call(%Plug.Conn{path_info: ["demos", name, "play"]} = conn, _opts) do
    serve_play_redirect(conn, name)
  end

  def call(conn, _opts), do: not_found(conn)

  defp serve_play_redirect(conn, name) do
    case DemoDirector.Demos.fetch(name) do
      {:ok, demo} ->
        js = DemoDirector.Demos.load_js(demo)
        start_at = demo.start_at || "/"
        html = render_play_redirect(js, start_at, demo.title)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      :error ->
        not_found(conn)
    end
  end

  defp render_play_redirect(js, start_at, title) do
    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Playing: #{escape(title)}</title>
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <style>
          body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            background: #0f172a;
            color: #94a3b8;
            font: 16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
          }
        </style>
      </head>
      <body>
        <p>Starting demo…</p>
        <script>
          sessionStorage.setItem(
            "demo_director:pending_demo",
            JSON.stringify({ js: #{Jason.encode!(js)} })
          );
          window.location.replace(#{Jason.encode!(start_at)});
        </script>
      </body>
    </html>
    """
  end

  defp serve_demo_js(conn, name) do
    case DemoDirector.Demos.fetch(name) do
      {:ok, demo} ->
        body =
          Jason.encode!(%{
            name: demo.name,
            title: demo.title,
            start_at: demo.start_at,
            js: DemoDirector.Demos.load_js(demo)
          })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)

      :error ->
        not_found(conn)
    end
  end

  defp not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "not found")
  end

  defp mount_path do
    Application.get_env(:demo_director, :mount_path, "/demo-director")
  end

  defp render_index(demos, mount_path) do
    rows =
      Enum.map(demos, fn demo ->
        """
        <li class="td-row">
          <div class="td-row__main">
            <h2 class="td-row__title">#{escape(demo.title)}</h2>
            <p class="td-row__meta">
              <code>#{escape(demo.name)}.exs</code>
              #{if demo.start_at, do: "<span>· starts at <code>#{escape(demo.start_at)}</code></span>", else: ""}
            </p>
          </div>
          <a
            class="td-row__play"
            href="#{escape(mount_path)}/demos/#{escape(demo.name)}/play"
          >Play</a>
        </li>
        """
      end)
      |> Enum.join("\n")

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Demo Director · Saved demos</title>
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <style>
          :root { color-scheme: dark; }
          body {
            margin: 0;
            background: #1f0e2e;
            color: #f5f3ff;
            font: 16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
          }
          .td-page { max-width: 720px; margin: 0 auto; padding: 48px 24px 96px; }
          .td-page__header { margin-bottom: 32px; }
          .td-page h1 {
            margin: 0 0 4px;
            font-size: 32px;
            line-height: 1.2;
            color: #c4b5fd;
          }
          .td-page__subhead {
            margin: 0 0 12px;
            font-size: 18px;
            font-weight: 500;
            color: #ddd6fe;
          }
          .td-page__lede { margin: 0; color: #a78bfa; }
          .td-list { list-style: none; padding: 0; margin: 0; display: grid; gap: 12px; }
          .td-row {
            display: flex;
            align-items: center;
            gap: 16px;
            padding: 16px 20px;
            background: #2d1b3d;
            border-radius: 12px;
            border: 1px solid #3d2554;
          }
          .td-row__main { flex: 1; min-width: 0; }
          .td-row__title { margin: 0 0 4px; font-size: 16px; color: #f5f3ff; }
          .td-row__meta { margin: 0; color: #a78bfa; font-size: 13px; }
          .td-row__meta code {
            background: #1f0e2e;
            padding: 1px 6px;
            border-radius: 4px;
            font-size: 12px;
            color: #ddd6fe;
          }
          .td-row__play {
            display: inline-block;
            padding: 8px 18px;
            background: #ef4444;
            color: white;
            font: inherit;
            font-weight: 600;
            border-radius: 8px;
            text-decoration: none;
          }
          .td-row__play:hover { background: #dc2626; text-decoration: none; }
          .td-empty {
            margin-top: 24px;
            padding: 24px;
            border-radius: 12px;
            background: #2d1b3d;
            border: 1px solid #3d2554;
            color: #a78bfa;
          }
          .td-empty code {
            background: #1f0e2e;
            padding: 1px 6px;
            border-radius: 4px;
            font-size: 13px;
            color: #ddd6fe;
          }
        </style>
      </head>
      <body>
        <main class="td-page">
          <header class="td-page__header">
            <h1>Demo Director</h1>
            <p class="td-page__subhead">Saved demos</p>
            <p class="td-page__lede">
              Click <strong>Play</strong> to navigate to the demo's starting
              page and run it. The overlay narrates the script, highlights
              the next element, and types at a readable speed.
            </p>
          </header>

          #{if demos == [],
            do: empty_state(),
            else: ~s|<ul class="td-list">#{rows}</ul>|}
        </main>
      </body>
    </html>
    """
  end

  defp empty_state do
    """
    <div class="td-empty">
      No demos found. Add <code>.exs</code> files to <code>priv/demos/</code>
      (or <code>dev/priv/demos/</code> when working on this package).
    </div>
    """
  end

  defp escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
