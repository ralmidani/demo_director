defmodule Mix.Tasks.DemoDirector.Play do
  @shortdoc "Prints a clickable URL that plays a saved demo in the browser"

  @moduledoc """
  Prints a URL you can open (or click in your terminal) that plays a
  saved DemoDirector demo against the running dev server.

  Opening the URL takes the browser through the demo's `@start_at`
  page with the demo's JS stashed in `sessionStorage`. The overlay
  consumes it on load and runs the demo end-to-end.

  ## Usage

      mix demo_director.play <name>

  Where `<name>` is the basename of an `.exs` file in `priv/demos/`
  (or, when running this package's own demos, `dev/priv/demos/`).

  Pass `--path PATH` to verify a script outside the default lookup:

      mix demo_director.play onboarding --path dev/priv/demos/onboarding.exs

  Pass `--url URL` to override the printed URL entirely:

      mix demo_director.play onboarding --url http://localhost:4000/dev/director/demos/onboarding/play

  By default the task derives the URL from a probe of the running
  server. Set `DD_HOST` (default `http://localhost:4000`) for non-default
  hosts/ports.

  The dev server must already be running.
  """

  use Mix.Task

  @switches [path: :string, url: :string]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, strict: @switches)

    name =
      case positional do
        [name | _] -> name
        [] -> Mix.raise("usage: mix demo_director.play <name> [--path PATH] [--url URL]")
      end

    if path = opts[:path] do
      unless File.exists?(path) do
        Mix.raise("demo script not found: #{path}")
      end
    else
      unless File.exists?(resolve_default_path(name)) do
        Mix.raise("demo script not found: #{resolve_default_path(name)}")
      end
    end

    {url, server_status} =
      case opts[:url] do
        nil -> resolve_play_url(name)
        explicit -> {explicit, :unchecked}
      end

    Mix.shell().info("Open this URL to play \"#{name}\":")
    Mix.shell().info("\n  #{url}\n")

    case server_status do
      :down ->
        Mix.shell().info(
          "(server doesn't appear to be running at #{host_root()} — start it with `mix dev`)"
        )

      _ ->
        :ok
    end
  end

  defp host_root do
    System.get_env("DD_HOST") || "http://localhost:4000"
  end

  defp resolve_default_path(name) do
    candidates = [
      Path.join(["priv", "demos", "#{name}.exs"]),
      Path.join(["dev", "priv", "demos", "#{name}.exs"])
    ]

    Enum.find(candidates, &File.exists?/1) || List.first(candidates)
  end

  # Returns `{url, :up | :down}`. When the server is reachable, probes
  # the configured mount paths and returns the live URL. When the
  # server is down (or not yet started), falls back to the package's
  # default mount path so the URL is still useful for copy-paste.
  defp resolve_play_url(name) do
    host = host_root()
    mount_paths = ["/dev/director", "/demo-director", "/director"]

    case Enum.find_value(mount_paths, fn mp -> probe_mount(host, mp, name) end) do
      nil ->
        # No probe succeeded. Either the server is down, or the host
        # has a non-standard mount. Fall back to the package default
        # and warn — the URL will still work once the server's up,
        # provided the mount matches the default.
        {host <> "/demo-director/demos/" <> name <> "/play", :down}

      url ->
        {url, :up}
    end
  end

  # Probe the per-demo play URL with HEAD; if it 200s, that mount is
  # the right one. Returns the GET URL or nil.
  defp probe_mount(host, mount_path, name) do
    url = host <> mount_path <> "/demos/" <> name <> "/play"
    {:ok, _} = Application.ensure_all_started(:inets)

    case :httpc.request(:head, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _, _}} -> url
      _ -> nil
    end
  end
end
