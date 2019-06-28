defmodule ForgeWorkshop.MixProject do
  use Mix.Project

  @top "../"
  @version @top |> Path.join("version") |> File.read!() |> String.trim()
  @elixir_version @top |> Path.join(".elixir_version") |> File.read!() |> String.trim()

  def get_version, do: @version
  def get_elixir_version, do: @elixir_version

  def project do
    [
      app: :forge_workshop,
      version: @version,
      elixir: @elixir_version,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps_path: Path.join(@top, "deps"),
      build_path: Path.join(@top, "_build"),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        forge_workshop: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      extra_applications: [:logger],
      mod: {ForgeWorkshop.Application, []}
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
      # Phoenix and Ecto
      {:phoenix, "~> 1.4.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_ecto, "~> 3.0"},
      {:ecto, "~> 2.2"},
      {:postgrex, "~> 0.13"},
      {:sqlite_ecto2, git: "https://github.com/tyrchen/sqlite_ecto2"},
      {:esqlite, git: "https://github.com/dingpl716/esqlite", override: true},

      # Common tools
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:httpoison, "~> 1.4"},
      {:poison, "~> 3.1"},
      {:drab, "~> 0.10"},

      # ArcBlock
      {:abt_did_elixir, "~> 0.3"},
      # {:abt_did_elixir, path: "../abt-did-elixir"},
      {:forge_sdk, "~> 0.30"},
      # {:forge_sdk, path: "../../forge-elixir-sdk", override: true},

      # utility tools for error logs and metrics
      {:ex_datadog_plug, "~> 0.5.0"},
      {:logger_sentry, "~> 0.2"},
      {:recon, "~> 2.3"},
      {:recon_ex, "~> 0.9.1"},
      {:sentry, "~> 7.0"},
      {:statix, "~> 1.1"},

      # dev & test
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false},
      {:excheck, "~> 0.6", only: :test, runtime: false},
      {:triq, "~> 1.3", only: :test, runtime: false},

      # test only
      {:ex_machina, "~> 2.2", only: [:dev, :test]},
      {:faker, "~> 0.11", only: [:dev, :test]},
      {:mock, "~> 0.3", only: [:dev, :test]},
      {:excoveralls, "~> 0.10", only: [:dev, :test]}
    ]
  end
end
