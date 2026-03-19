defmodule AshUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_ui,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AshUI.Application, []}
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:jason, "~> 1.4"},
      {:postgrex, ">= 0.0.0"},
      {:ecto_sql, "~> 3.10"}
    ]
  end

  defp aliases do
    [
      format: ["format"]
    ]
  end
end
