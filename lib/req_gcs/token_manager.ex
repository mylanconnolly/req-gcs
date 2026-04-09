defmodule ReqGCS.TokenManager do
  @moduledoc false

  @doc false
  def fetch_token(credentials) when is_map(credentials) do
    name = credentials_name(credentials)

    case ensure_started(name, credentials) do
      :ok ->
        ReqGCS.TokenSweeper.touch(name)
        Goth.fetch(name)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp credentials_name(credentials) do
    hash =
      credentials
      |> Enum.sort()
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))

    {__MODULE__, hash}
  end

  defp ensure_started(name, credentials) do
    case Registry.lookup(Goth.Registry, name) do
      [{_pid, _value}] ->
        :ok

      [] ->
        child_spec = %{
          id: name,
          start:
            {Goth, :start_link,
             [
               [
                 name: name,
                 source: {:service_account, credentials}
               ]
             ]},
          restart: :transient
        }

        case DynamicSupervisor.start_child(ReqGCS.DynamicSupervisor, child_spec) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
