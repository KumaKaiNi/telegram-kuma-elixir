defmodule KumaBot.Mixfile do
  use Mix.Project

  def project do
    [app: :kuma_bot,
     version: "3.0.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :nadia],
     mod: {KumaBot, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:httpoison, "~> 1.1.1"},
     {:poison, "~> 3.1"},
     {:nadia, git: "https://github.com/zhyu/nadia"}]
  end
end
