defmodule Samly.Mixfile do
  use Mix.Project

  @version "0.7.2"
  @description "SAML SP SSO made easy"
  @source_url "https://github.com/handnot2/samly"

  def project() do
    [
      app: :samly,
      version: @version,
      description: @description,
      docs: docs(),
      package: package(),
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:plug, "~> 1.4"},
      {:esaml, "~> 3.1"},
      {:ex_doc, "~> 0.16", only: :dev},
      {:inch_ex, "~> 0.5", only: :docs},
    ]
  end

  defp docs() do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
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
