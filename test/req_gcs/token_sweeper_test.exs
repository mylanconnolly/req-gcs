defmodule ReqGCS.TokenSweeperTest do
  use ExUnit.Case, async: true

  test "touch/1 records an entry in the ETS table" do
    name = {:test_sweeper, make_ref()}
    ReqGCS.TokenSweeper.touch(name)

    assert [{^name, timestamp}] = :ets.lookup(ReqGCS.TokenSweeper, name)
    assert is_integer(timestamp)

    # Clean up
    :ets.delete(ReqGCS.TokenSweeper, name)
  end

  test "touch/1 updates the timestamp on subsequent calls" do
    name = {:test_sweeper, make_ref()}
    ReqGCS.TokenSweeper.touch(name)
    [{_, t1}] = :ets.lookup(ReqGCS.TokenSweeper, name)

    # Small sleep to ensure monotonic time advances
    Process.sleep(1)
    ReqGCS.TokenSweeper.touch(name)
    [{_, t2}] = :ets.lookup(ReqGCS.TokenSweeper, name)

    assert t2 >= t1

    # Clean up
    :ets.delete(ReqGCS.TokenSweeper, name)
  end

  test "sweep removes entries older than max_idle" do
    name = {:test_sweeper_old, make_ref()}

    # Insert an entry with a very old timestamp (1 hour + 1 second ago)
    old_time = System.monotonic_time(:millisecond) - 3_601_000
    :ets.insert(ReqGCS.TokenSweeper, {name, old_time})

    # Trigger a sweep by sending the message directly to the sweeper
    send(ReqGCS.TokenSweeper, :sweep)

    # Give the sweeper a moment to process
    Process.sleep(50)

    # The old entry should be gone
    assert :ets.lookup(ReqGCS.TokenSweeper, name) == []
  end

  test "sweep keeps entries newer than max_idle" do
    name = {:test_sweeper_new, make_ref()}
    ReqGCS.TokenSweeper.touch(name)

    send(ReqGCS.TokenSweeper, :sweep)
    Process.sleep(50)

    # The recent entry should still be there
    assert [{^name, _}] = :ets.lookup(ReqGCS.TokenSweeper, name)

    # Clean up
    :ets.delete(ReqGCS.TokenSweeper, name)
  end
end
