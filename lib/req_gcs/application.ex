defmodule ReqGCS.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: ReqGCS.DynamicSupervisor, strategy: :one_for_one},
      {ReqGCS.TokenSweeper, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
