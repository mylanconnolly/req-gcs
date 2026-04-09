defmodule ReqGCSTest do
  use ExUnit.Case, async: true

  test "attach/2 registers options and adds auth step" do
    req = Req.new() |> ReqGCS.attach()
    assert :gcs_credentials in req.registered_options
    assert :gcs_goth in req.registered_options
    assert :gcs_project in req.registered_options
    assert Keyword.has_key?(req.request_steps, :gcs_auth)
  end

  test "attach/2 merges provided options" do
    req = Req.new() |> ReqGCS.attach(gcs_project: "my-project")
    assert req.options[:gcs_project] == "my-project"
  end

  test "auth step is skipped when :auth is already set" do
    Req.Test.stub(ReqGCSTest.AuthSkip, fn conn ->
      [auth] = Plug.Conn.get_req_header(conn, "authorization")
      assert auth == "Bearer pre-set-token"
      Req.Test.json(conn, %{"kind" => "storage#buckets", "items" => []})
    end)

    req =
      Req.new(plug: {Req.Test, ReqGCSTest.AuthSkip})
      |> ReqGCS.attach(gcs_project: "test-project")

    assert {:ok, %{status: 200}} =
             ReqGCS.list_buckets(req, auth: {:bearer, "pre-set-token"})
  end
end
