defmodule ReqGCS.AuthTest do
  use ExUnit.Case, async: true

  test "returns error when no credentials are configured" do
    assert {:error, %RuntimeError{message: message}} =
             ReqGCS.Auth.fetch_token(%{})

    assert message =~ "No GCS credentials found"
  end

  test "prefers gcs_goth over gcs_credentials" do
    # gcs_goth takes priority — if it's set, gcs_credentials is not consulted.
    # Goth.fetch/1 exits when the process doesn't exist, confirming it was called
    # (rather than falling through to gcs_credentials).
    assert catch_exit(
             ReqGCS.Auth.fetch_token(%{
               gcs_goth: :nonexistent_goth_process,
               gcs_credentials: %{"should" => "not be used"}
             })
           )
  end
end
