defmodule Statix.Mixfile do
  use Mix.Project

  def project do
    [app: :statix,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     description: "Assembly of static websites from Mustache templates and JSON",
     deps: deps()]
  end

  def application do
    [applications: [:logger, :mustachex, :dir_walker, :poison, :inflex]]
  end

  defp deps do
    [{:mustachex, "~> 0.0.1"},
     {:dir_walker, "~> 0.0.6"},
     {:poison, "~> 2.0"},
     { :inflex, "~> 1.7.0" }]
  end

  defp package do
    [contributors: ["Dejan Strbac"],
     licenses: ["MIT License"],
     links: %{"GitHub" => "https://github.com/Advite/statix"},
     files: ~w(mix.exs README.md lib)]
  end
end