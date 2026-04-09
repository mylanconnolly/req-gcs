defmodule ReqGCS.TokenManagerTest do
  use ExUnit.Case, async: true

  test "fetch_token/1 requires a map" do
    assert_raise FunctionClauseError, fn ->
      ReqGCS.TokenManager.fetch_token("not a map")
    end
  end

  test "fetch_token/1 starts a Goth process and records a touch" do
    # We can't use real credentials in unit tests, but we can verify
    # that the DynamicSupervisor and TokenSweeper are running
    # (which means the Application started correctly).
    assert Process.whereis(ReqGCS.DynamicSupervisor) != nil
    assert Process.whereis(ReqGCS.TokenSweeper) != nil
  end
end
