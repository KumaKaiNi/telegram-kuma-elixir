defmodule KumaBot do
  unless File.exists?("_data"), do: File.mkdir("_data")
  unless File.exists?("_data/deps"), do: File.mkdir("_data/deps")
  unless File.exists?("_data/temp"), do: File.mkdir("_data/temp")
  unless File.exists?("_data/db"), do: File.mkdir("_data/db")

  def start(_type, _args) do
    import Supervisor.Spec
    children = [supervisor(KumaBot.Bot, [[name: KumaBot.Bot]])]
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
