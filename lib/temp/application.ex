defmodule Temp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Temp.Streamer, "xrpusdt"},
      Supervisor.child_spec({Temp.Worker, 60}, id: :worker_60s),
      Supervisor.child_spec({Temp.Worker, 60 * 5}, id: :worker_5m),
      Supervisor.child_spec({Temp.Worker, 60 * 15}, id: :worker_15m),
      Supervisor.child_spec({Temp.Worker, 60 * 60}, id: :worker_1h),
      Supervisor.child_spec({Temp.Worker, 60 * 60 * 4}, id: :worker_4h),
      Supervisor.child_spec({Temp.Worker, 60 * 60 * 8}, id: :worker_8h),
      Supervisor.child_spec({Temp.Worker, 60 * 60 * 24}, id: :worker_24h),
      # Starts a worker by calling: Temp.Worker.start_link(arg)
      # {Temp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Temp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
