if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.DemoDirector.Install do
    @shortdoc "Installs demo_director into your Phoenix project"

    @moduledoc """
    Installs `demo_director` into a Phoenix application.

    Run via:

        mix igniter.install demo_director

    Assumes the host app already has a working Phoenix LiveView setup
    (a `Phoenix.LiveView.Socket` declaration in the endpoint, a
    router, and the standard layouts). The installer doesn't
    bootstrap LiveView from scratch.

    The task does four things:

      1. Adds `import DemoDirector.Router` and a
         `demo_director "/demo-director"` macro call inside an
         `if Application.compile_env(:my_app, :dev_routes) do ... end`
         block in your router (creating the block if absent). The
         scope is *not* piped through `:browser` because the playback
         POST endpoint must bypass `protect_from_forgery`.
      2. Adds a `socket "/director/socket", DemoDirector.PlaybackSocket`
         declaration to your endpoint, after the existing
         `Phoenix.LiveView.Socket` line.
      3. Adds `config :demo_director, pubsub: <OtpApp>.PubSub` to
         `config/dev.exs` (using the conventional PubSub name from
         `mix phx.new`; if your PubSub server is named differently,
         edit the value after install).
      4. Appends a marked instructions section to `AGENTS.md` (always)
         and to `CLAUDE.md` (only if it already exists, or if a
         `.claude/` directory is present).

    One manual step remains — rendering the overlay component in
    your dev-time root layout — because root layouts are HEEx, not
    Elixir AST, so editing them programmatically means string-level
    surgery on a frequently-customized file. The post-install
    notice prints the exact line to paste.

    Sections written to `AGENTS.md` / `CLAUDE.md` are wrapped in
    `<!-- BEGIN demo_director -->` / `<!-- END demo_director -->`
    markers, so re-running the task replaces the section in place
    rather than appending a duplicate. Router and endpoint edits
    are similarly idempotent — the task searches for an existing
    `import DemoDirector.Router` / `DemoDirector.PlaybackSocket`
    before adding.
    """

    use Igniter.Mix.Task

    @router_path "/demo-director"
    @begin_marker "<!-- BEGIN demo_director -->"
    @end_marker "<!-- END demo_director -->"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :demo_director,
        example: "mix igniter.install demo_director"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> install_router_macro()
      |> install_endpoint_socket()
      |> install_pubsub_config()
      |> install_agent_docs()
      |> add_layout_reminder()
    end

    # --- router edit -------------------------------------------------------

    defp install_router_macro(igniter) do
      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which router should mount demo_director?"
        )

      if router do
        Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
          # Skip if `import DemoDirector.Router` is already present in the
          # router — keeps re-runs idempotent.
          case Igniter.Code.Common.move_to(zipper, &demo_director_imported?/1) do
            {:ok, _} ->
              {:ok, zipper}

            :error ->
              {:ok,
               Igniter.Code.Common.add_code(
                 zipper,
                 """
                 if Application.compile_env(:#{otp_app()}, :dev_routes) do
                   import DemoDirector.Router

                   scope "/dev" do
                     demo_director "#{@router_path}"
                   end
                 end
                 """,
                 placement: :after
               )}
          end
        end)
      else
        Igniter.add_warning(igniter, """
        No router found. Add the following to your router manually:

            if Application.compile_env(:my_app, :dev_routes) do
              import DemoDirector.Router

              scope "/dev" do
                demo_director "#{@router_path}"
              end
            end
        """)
      end
    end

    defp demo_director_imported?(zipper) do
      Igniter.Code.Function.function_call?(zipper, :import, 1) and
        Igniter.Code.Function.argument_equals?(zipper, 0, DemoDirector.Router)
    end

    # --- endpoint socket ---------------------------------------------------

    @socket_example """
        socket "/director/socket", DemoDirector.PlaybackSocket,
          websocket: true,
          longpoll: false
    """

    defp install_endpoint_socket(igniter) do
      {igniter, endpoint} =
        Igniter.Libs.Phoenix.select_endpoint(
          igniter,
          nil,
          "Which endpoint should serve demo_director?"
        )

      if endpoint do
        add_socket_to_endpoint(igniter, endpoint)
      else
        Igniter.add_warning(igniter, """
        No endpoint found. Add the playback socket manually:

        #{@socket_example}
        """)
      end
    end

    defp add_socket_to_endpoint(igniter, endpoint) do
      Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        with :error <- Igniter.Code.Common.move_to(zipper, &playback_socket?/1),
             {:ok, zipper} <- Igniter.Code.Common.move_to(zipper, &live_view_socket?/1) do
          {:ok,
           Igniter.Code.Common.add_code(
             zipper,
             """
             socket "/director/socket", DemoDirector.PlaybackSocket,
               websocket: true,
               longpoll: false
             """,
             placement: :after
           )}
        else
          {:ok, _} ->
            {:ok, zipper}

          :error ->
            {:warning,
             """
             Could not find a `socket "/live", Phoenix.LiveView.Socket` declaration in `#{inspect(endpoint)}`.
             demo_director assumes a working Phoenix LiveView setup. Please add the playback socket manually:

             #{@socket_example}
             """}
        end
      end)
    end

    defp playback_socket?(zipper) do
      Igniter.Code.Function.function_call?(zipper, :socket) and
        Igniter.Code.Function.argument_equals?(zipper, 1, DemoDirector.PlaybackSocket)
    end

    defp live_view_socket?(zipper) do
      Igniter.Code.Function.function_call?(zipper, :socket) and
        Igniter.Code.Function.argument_equals?(zipper, 1, Phoenix.LiveView.Socket)
    end

    # --- pubsub config -----------------------------------------------------

    defp install_pubsub_config(igniter) do
      Igniter.Project.Config.configure(
        igniter,
        "dev.exs",
        :demo_director,
        [:pubsub],
        {:code, Sourceror.parse_string!("#{module_name(otp_app())}.PubSub")}
      )
    end

    # --- agent docs --------------------------------------------------------

    defp install_agent_docs(igniter) do
      igniter
      |> upsert_agent_doc("AGENTS.md", :always)
      |> upsert_agent_doc("CLAUDE.md", :detect)
    end

    defp upsert_agent_doc(igniter, filename, mode) do
      should_write? =
        case mode do
          :always -> true
          :detect -> File.exists?(filename) or File.dir?(".claude")
        end

      if should_write? do
        contents = render_section()

        new_text =
          if File.exists?(filename) do
            replace_or_append_section(File.read!(filename), contents)
          else
            contents <> "\n"
          end

        Igniter.create_or_update_file(igniter, filename, new_text, fn source ->
          Rewrite.Source.update(source, :content, new_text)
        end)
      else
        igniter
      end
    end

    defp replace_or_append_section(existing, new_section) do
      pattern =
        ~r/#{Regex.escape(@begin_marker)}.*?#{Regex.escape(@end_marker)}/s

      if Regex.match?(pattern, existing) do
        Regex.replace(pattern, existing, new_section, global: false)
      else
        trimmed = String.trim_trailing(existing)
        trimmed <> "\n\n" <> new_section <> "\n"
      end
    end

    defp render_section do
      :demo_director
      |> Application.app_dir("priv/templates/instructions.md")
      |> File.read!()
      |> String.trim()
    end

    # --- layout reminder ---------------------------------------------------

    defp add_layout_reminder(igniter) do
      Igniter.add_notice(igniter, """
      demo_director is almost installed. One step remains — it stays
      manual because root layouts are HEEx, not Elixir, so editing
      them programmatically would mean string-level surgery against a
      file users frequently customize:

          Render the overlay in your dev-time root layout
          (`lib/#{otp_app()}_web/components/layouts/root.html.heex`):

              <DemoDirector.Components.demo_director_overlay />

      The component itself returns empty markup whenever the router
      macro hasn't registered a mount path, so the line is safe to
      leave inside `<body>` even in prod.
      """)
    end

    defp module_name(otp_app) do
      otp_app
      |> to_string()
      |> Macro.camelize()
    end

    # --- helpers -----------------------------------------------------------

    defp otp_app do
      Mix.Project.config()[:app] || :my_app
    end
  end
else
  defmodule Mix.Tasks.DemoDirector.Install do
    @shortdoc "Installs demo_director (requires igniter)"
    @moduledoc false

    use Mix.Task

    @impl Mix.Task
    def run(_args) do
      Mix.raise("""
      mix demo_director.install requires igniter to be installed.

      Add to your mix.exs deps:

          {:igniter, "~> 0.6", only: [:dev]}

      Then run `mix deps.get` and try again.
      """)
    end
  end
end
