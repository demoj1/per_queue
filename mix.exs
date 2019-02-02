defmodule Queue.MixProject do
  use Mix.Project

  def project do
    [
      app: :queue,
      version: "0.2.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      description: "An elixir queue library",
      name: "Queue",
      source_url: "https://github.com/dmitrydprog/per_queue",
      homepage_url: "https://dmitrydprog.github.io/per_queue/Queue.html",
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Queue, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:memento, "~> 0.2.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:benchee, "~> 0.13", only: :dev, runtime: false}
    ]
  end
end
