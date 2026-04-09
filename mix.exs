defmodule ReqGCS.MixProject do
  use Mix.Project

  def project do
    [
      app: :req_gcs,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ReqGCS.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:goth, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:plug, "~> 1.0", only: :test}
    ]
  end
end
