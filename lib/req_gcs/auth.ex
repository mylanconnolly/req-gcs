defmodule ReqGCS.Auth do
  @moduledoc false

  @doc false
  def fetch_token(options) do
    cond do
      goth_name = options[:gcs_goth] ->
        Goth.fetch(goth_name)

      credentials = options[:gcs_credentials] ->
        ReqGCS.TokenManager.fetch_token(credentials)

      credentials = Application.get_env(:req_gcs, :credentials) ->
        ReqGCS.TokenManager.fetch_token(credentials)

      true ->
        {:error,
         %RuntimeError{
           message:
             "No GCS credentials found. Provide credentials via one of:\n" <>
               "  - Per-request option: gcs_credentials: parsed_json_map\n" <>
               "  - Named Goth process: gcs_goth: MyApp.Goth\n" <>
               "  - Application config: config :req_gcs, credentials: parsed_json_map"
         }}
    end
  end
end
