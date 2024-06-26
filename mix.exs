defmodule Dojo.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dojo,
      version: "1.6.2",
      elixir: "~> 1.14.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Dojo.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.4"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.9.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.16.4"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.5"},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20.0"},
      {:jason, "~> 1.4.0"},
      {:plug_cowboy, "~> 2.5.2"},
      {:plug_crypto, "~> 1.2.2"},
      {:binbo, "~> 4.0.2"},
      {:uuid, "~> 1.1"},

      # Wake Heroku App. See: https://github.com/dwyl/ping
      {:ping, "~> 1.1.0"},

      # sanitise data to avoid XSS see: https://git.io/fjpGZ
      {:html_sanitize_ex, "~> 1.4"},

      # The rest of the dependendencies are for testing/reporting
      # tracking test coverage
      {:excoveralls, "~> 0.15.0", only: [:test, :dev]},
      # documentation
      {:inch_ex, "~> 2.1.0-rc.1", only: :docs},
      # github.com/dwyl/learn-pre-commit
      {:pre_commit, "~> 0.3.4", only: :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      cover: ["coveralls.json"],
      "cover.html": ["coveralls.html"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
