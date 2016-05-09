defmodule Sqlcx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :sqlcx,
      version: "1.2.0",
      elixir: "~> 1.4",
      deps: deps(),
      package: package(),
      source_url: "https://github.com/FelixKiunke/sqlcx",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.circle": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      description: """
      A thin Elixir wrapper around esqlcipher
      """,
      dialyzer: [plt_add_deps: :transitive],
      # The main page in the docs
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  def application do
    [extra_applications: [:logger]]
  end

  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:esqlcipher, "~> 1.1"},
      {:decimal, "~> 2.0"},
      {:credo, "~> 0.10", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: :test},
      {:ex_doc, "~> 0.23", only: :docs, runtime: false},
      {:excheck, "~> 0.6", only: :test},
      {:triq, "~> 1.3", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Felix Kiunke"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/FelixKiunke/sqlcx",
        "docs" => "http://hexdocs.pm/sqlcx"
      }
    ]
  end
end
