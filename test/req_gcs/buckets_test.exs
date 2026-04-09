defmodule ReqGCS.BucketsTest do
  use ExUnit.Case, async: true

  defp new_req(stub_name) do
    Req.new(plug: {Req.Test, stub_name})
    |> ReqGCS.attach(gcs_project: "my-project")
  end

  test "list_buckets sends GET /storage/v1/b with project param" do
    Req.Test.stub(__MODULE__.ListBuckets, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/storage/v1/b"

      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["project"] == "my-project"

      Req.Test.json(conn, %{"kind" => "storage#buckets", "items" => []})
    end)

    assert {:ok, %{status: 200, body: %{"items" => []}}} =
             ReqGCS.list_buckets(new_req(__MODULE__.ListBuckets),
               auth: {:bearer, "t"}
             )
  end

  test "get_bucket sends GET /storage/v1/b/{bucket}" do
    Req.Test.stub(__MODULE__.GetBucket, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/storage/v1/b/my-bucket"

      Req.Test.json(conn, %{"kind" => "storage#bucket", "name" => "my-bucket"})
    end)

    assert {:ok, %{status: 200, body: %{"name" => "my-bucket"}}} =
             ReqGCS.get_bucket(new_req(__MODULE__.GetBucket), "my-bucket", auth: {:bearer, "t"})
  end

  test "create_bucket sends POST /storage/v1/b with project and JSON body" do
    Req.Test.stub(__MODULE__.CreateBucket, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/storage/v1/b"

      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["project"] == "my-project"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"name" => "new-bucket"} = Jason.decode!(body)

      Req.Test.json(conn, %{"kind" => "storage#bucket", "name" => "new-bucket"})
    end)

    assert {:ok, %{status: 200, body: %{"name" => "new-bucket"}}} =
             ReqGCS.create_bucket(
               new_req(__MODULE__.CreateBucket),
               %{"name" => "new-bucket"},
               auth: {:bearer, "t"}
             )
  end

  test "update_bucket sends PATCH /storage/v1/b/{bucket} with JSON body" do
    Req.Test.stub(__MODULE__.UpdateBucket, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/storage/v1/b/my-bucket"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"versioning" => %{"enabled" => true}} = Jason.decode!(body)

      Req.Test.json(conn, %{"kind" => "storage#bucket", "name" => "my-bucket"})
    end)

    assert {:ok, %{status: 200}} =
             ReqGCS.update_bucket(
               new_req(__MODULE__.UpdateBucket),
               "my-bucket",
               %{"versioning" => %{"enabled" => true}},
               auth: {:bearer, "t"}
             )
  end

  test "delete_bucket sends DELETE /storage/v1/b/{bucket}" do
    Req.Test.stub(__MODULE__.DeleteBucket, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/storage/v1/b/my-bucket"

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{status: 204}} =
             ReqGCS.delete_bucket(new_req(__MODULE__.DeleteBucket), "my-bucket",
               auth: {:bearer, "t"}
             )
  end

  test "list_buckets raises when project is missing" do
    req = Req.new() |> ReqGCS.attach()

    assert_raise ArgumentError, ~r/GCS project is required/, fn ->
      ReqGCS.list_buckets(req, auth: {:bearer, "t"})
    end
  end
end
