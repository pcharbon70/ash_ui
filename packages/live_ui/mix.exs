defmodule LiveUi.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/pcharbon70/unified_ui"

  def project do
    [
      app: :live_ui,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: "Phoenix LiveView runtime library for the unified ecosystem.",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:earmark, "~> 1.4"},
      {:html_sanitize_ex, "~> 1.4"},
      {:jido_signal, "~> 2.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:plug_cowboy, "~> 2.7"},
      {:unified_iur, path: "../unified_iur"}
    ]
  end

  defp docs do
    [
      main: "LiveUi",
      extras: [
        "README.md",
        "guides/runtime_backbone.md",
        "guides/native_runtime_and_examples.md",
        "guides/canonical_rendering_and_transport.md",
        "guides/maintainer_workflows.md"
      ],
      source_ref: "main",
      source_url: @source_url
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
