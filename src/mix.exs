defmodule AbtDidWorkshop.MixProject do
  use Mix.Project

  @version File.cwd!() |> Path.join("../version") |> File.read!() |> String.trim()
  @elixir_version File.cwd!() |> Path.join(".elixir_version") |> File.read!() |> String.trim()
  @otp_version File.cwd!() |> Path.join(".otp_version") |> File.read!() |> String.trim()

  def get_version, do: @version
  def get_elixir_version, do: @elixir_version
  def get_otp_version, do: @otp_version

  def project do
    [
      app: :abt_did_workshop,
      version: @version,
      elixir: @elixir_version,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AbtDidWorkshop.Application, []},
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
      {:phoenix, "~> 1.4.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:httpoison, "~> 1.4"},
      {:drab, "~> 0.10"},

      # ArcBlock
      {:abt_did_elixir, git: "git@github.com:arcblock/abt-did-elixir.git", tag: "v0.1.17"},
      # {:forge_sdk, path: "~/Documents/GitHub/ArcBlock/forge-elixir-sdk"},
      {:forge_sdk, git: "git@github.com:arcblock/forge-elixir-sdk.git"},

      # utility tools for error logs and metrics
      {:ex_datadog_plug, "~> 0.5.0"},
      {:logger_sentry, "~> 0.2"},
      {:recon, "~> 2.3"},
      {:recon_ex, "~> 0.9.1"},
      {:sentry, "~> 7.0"},
      {:statix, "~> 1.1"},

      # deployment
      {:distillery, "~> 2.0", runtime: false},

      # dev & test
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false},
      {:excheck, "~> 0.6", only: :test, runtime: false},
      {:pre_commit_hook, "~> 1.2", only: [:dev, :test], runtime: false},
      {:triq, "~> 1.3", only: :test, runtime: false},

      # test only
      {:ex_machina, "~> 2.2", only: [:dev, :test]},
      {:faker, "~> 0.11", only: [:dev, :test]},
      {:mock, "~> 0.3", only: [:dev, :test]},
      {:excoveralls, "~> 0.10", only: [:dev, :test]}
    ]
  end
end
