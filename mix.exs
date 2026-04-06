defmodule Conjure.MixProject do
  use Mix.Project

  def project do
    [
      app: :conjure,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto, :os_mon]]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:zigler, "~> 0.15", runtime: false}
    ]
  end
end
