if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.DemoDirector.Install do
    @shortdoc "Installs demo_director into your Phoenix project"

    @moduledoc """
    Installs `demo_director` into a Phoenix application.

    Run via:

        mix igniter.install demo_director

    The task does three things:

      1. Adds `import DemoDirector.Router` and a
         `demo_director "/demo-director"` macro call inside an
         `if Application.compile_env(:my_app, :dev_routes) do ... end`
         block in your router (creating the block if absent). The
         scope is *not* piped through `:browser` because the playback
         POST endpoint must bypass `protect_from_forgery`.
      2. Appends a marked instructions section to `AGENTS.md` (always)
         and to `CLAUDE.md` (only if it already exists, or if a
         `.claude/` directory is present).
      3. Prints a post-install message reminding you of the remaining
         manual steps: adding the playback socket to your endpoint,
         setting the `:pubsub` config, and rendering the overlay
         component in your layout. We don't auto-edit those because
         endpoint and layout structure vary too much across apps.

    Sections written to `AGENTS.md` / `CLAUDE.md` are wrapped in
    `<!-- BEGIN demo_director -->` / `<!-- END demo_director -->`
    markers, so re-running the task replaces the section in place
    rather than appending a duplicate.
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
          # We just append the import + macro call inside the router
          # module body. Igniter's de-dup keeps this idempotent on
          # re-runs.
          zipper
          |> Igniter.Code.Common.add_code(
            """
            if Application.compile_env(:#{otp_app()}, :dev_routes) do
              import DemoDirector.Router

              scope "/dev" do
                demo_director "#{@router_path}"
              end
            end
            """,
            placement: :after
          )
          |> then(&{:ok, &1})
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

        Igniter.create_or_update_file(igniter, filename, new_text, fn _ -> new_text end)
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
      demo_director is partially installed. Three steps remain — they
      depend on your endpoint and layout structure, so we don't auto-edit:

      1. Add the playback socket to your endpoint
         (`lib/#{otp_app()}_web/endpoint.ex`), alongside the existing
         Phoenix.LiveView.Socket:

             socket "/director/socket", DemoDirector.PlaybackSocket,
               websocket: true,
               longpoll: false

      2. Configure the PubSub server (typically in `config/dev.exs`):

             config :demo_director, pubsub: #{module_name(otp_app())}.PubSub

      3. Render the overlay in your dev-time root layout
         (`lib/#{otp_app()}_web/components/layouts/root.html.heex`):

             <DemoDirector.Components.demo_director_overlay />

      These render nothing in prod when the router macro hasn't been
      compiled in (which is the default when :dev_routes is unset).
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
