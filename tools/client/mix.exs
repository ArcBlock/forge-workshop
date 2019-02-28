defmodule Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :client,
      version: "0.1.0",
      elixir: "~> 1.7",
      build_path: "../../src/_build",
      deps_path: "../../src/deps",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Client.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:httpoison, "~> 1.4"},
      {:abt_did_elixir, git: "git@github.com:arcblock/abt-did-elixir.git", tag: "v0.1.17"},
      {:forge_sdk, git: "git@github.com:arcblock/forge-elixir-sdk.git"},
      {:multibase, "~> 0.0.1"}
    ]
  end
end
