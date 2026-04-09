defmodule ReqGCS.TokenSweeper do
  @moduledoc false

  use GenServer

  @table __MODULE__
  @default_sweep_interval 300_000
  @default_max_idle 3_600_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def touch(name) do
    if :ets.whereis(@table) != :undefined do
      :ets.insert(@table, {name, System.monotonic_time(:millisecond)})
    end

    :ok
  end

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    sweep_interval =
      Application.get_env(:req_gcs, :sweep_interval, @default_sweep_interval)

    max_idle = Application.get_env(:req_gcs, :max_idle, @default_max_idle)

    schedule_sweep(sweep_interval)
    {:ok, %{table: table, sweep_interval: sweep_interval, max_idle: max_idle}}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)

    :ets.foldl(
      fn {name, last_access}, :ok ->
        if now - last_access > state.max_idle do
          case Registry.lookup(Goth.Registry, name) do
            [{pid, _}] ->
              DynamicSupervisor.terminate_child(ReqGCS.DynamicSupervisor, pid)

            [] ->
              :ok
          end

          :ets.delete(@table, name)
        end

        :ok
      end,
      :ok,
      @table
    )

    schedule_sweep(state.sweep_interval)
    {:noreply, state}
  end

  defp schedule_sweep(interval) do
    Process.send_after(self(), :sweep, interval)
  end
end
