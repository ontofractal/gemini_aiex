defmodule Geminiex.MixProject do
  use Mix.Project

  def project do
    [
      app: :geminiex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Geminiex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:typed_struct, "~> 0.3.0"},
      {:nimble_options, "~> 1.1"}
    ]
  end
end
