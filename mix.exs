defmodule DemoDirector.MixProject do
  use Mix.Project

  @version "0.1.6"
  @source_url "https://github.com/ralmidani/demo_director"

  def project do
    [
      app: :demo_director,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      listeners: listeners(Mix.env()),
      description: description(),
      package: package(),
      docs: docs(),
      name: "DemoDirector",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp aliases do
    [dev: "run --no-halt dev.exs"]
  end

  defp listeners(:dev), do: [Phoenix.CodeReloader]
  defp listeners(_), do: []

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:igniter, "~> 0.6", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Dev demo server — boot via `mix dev`. phoenix and phoenix_html
      # are pulled in transitively by phoenix_live_view.
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:bandit, "~> 1.5", only: :dev},
      {:earmark, "~> 1.4", only: :dev},
      {:tidewave, "~> 0.5", only: :dev}
    ]
  end

  defp description do
    "Reproducible, replayable demos for Phoenix LiveView — author reusable scripts, with or without AI."
  end

  defp package do
    [
      maintainers: ["Ragheed Al-midani"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      extra_section: "GUIDES",
      source_ref: "v#{@version}",
      groups_for_modules: [
        Authoring: [
          DemoDirector,
          DemoDirector.Components,
          DemoDirector.HEEx,
          DemoDirector.Router
        ],
        "Mix Tasks": [
          Mix.Tasks.DemoDirector.Install,
          Mix.Tasks.DemoDirector.Play
        ],
        Internals: [
          DemoDirector.Demos,
          DemoDirector.Playback,
          DemoDirector.PlaybackChannel,
          DemoDirector.PlaybackSocket,
          DemoDirector.Plug.Index,
          DemoDirector.Plug.Play,
          DemoDirector.Plug.Static
        ]
      ]
    ]
  end
end
