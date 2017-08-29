defmodule Samly.Mixfile do
  use Mix.Project

  @version "0.2.0"
  @description "SAML plug"
  @source_url "https://github.com/handnot2/samly"

  def project do
    [
      app: :samly,
      version: @version,
      description: @description,
      package: package(),
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.4"},
      {:cowboy, "~> 1.1", override: true},
      {:esaml, github: "VendorHawk/esaml"},
      {:ex_doc, "~> 0.16", only: :dev},
    ]
  end

  defp package() do
    [
      maintainers: ["handnot2"],
      files: ["config", "lib", "LICENSE", "mix.exs", "README.md"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
      }
    ]
  end
end
