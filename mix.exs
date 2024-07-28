defmodule Talkoyaki.MixProject do
  use Mix.Project

  def project do
    [
      app: :talkoyaki,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Talkoyaki.Application, []},
      extra_applications: [:logger, :certifi, :gun, :inets, :jason, :mime],
      included_applications: [:nostrum]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # CI
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # Discord
      {:nostrum, github: "Kraigie/nostrum", branch: "master", override: true, runtime: false},
      #{:nosedrum,
      # github: "jchristgit/nosedrum", branch: "master", override: true},
      # Efficient gateway compression
      {:ezstd, "~> 1.1"},
      # Mnesia
      {:memento, "~> 0.3.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
