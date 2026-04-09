defmodule ReqGCS.ObjectsTest do
  use ExUnit.Case, async: true

  defp new_req(stub_name) do
    Req.new(plug: {Req.Test, stub_name})
    |> ReqGCS.attach(gcs_project: "my-project")
  end

  test "list_objects sends GET /storage/v1/b/{bucket}/o" do
    Req.Test.stub(__MODULE__.ListObjects, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/storage/v1/b/my-bucket/o"

      Req.Test.json(conn, %{"kind" => "storage#objects", "items" => []})
    end)

    assert {:ok, %{status: 200, body: %{"items" => []}}} =
             ReqGCS.list_objects(new_req(__MODULE__.ListObjects), "my-bucket",
               auth: {:bearer, "t"}
             )
  end

  test "list_objects forwards prefix, delimiter, max_results, page_token" do
    Req.Test.stub(__MODULE__.ListObjectsParams, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["prefix"] == "logs/"
      assert conn.query_params["delimiter"] == "/"
      assert conn.query_params["maxResults"] == "10"
      assert conn.query_params["pageToken"] == "abc123"

      Req.Test.json(conn, %{"kind" => "storage#objects", "items" => []})
    end)

    assert {:ok, %{status: 200}} =
             ReqGCS.list_objects(new_req(__MODULE__.ListObjectsParams), "my-bucket",
               prefix: "logs/",
               delimiter: "/",
               max_results: 10,
               page_token: "abc123",
               auth: {:bearer, "t"}
             )
  end

  test "get_object sends GET /storage/v1/b/{bucket}/o/{object}" do
    Req.Test.stub(__MODULE__.GetObject, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/storage/v1/b/my-bucket/o/path%2Fto%2Ffile.txt"

      Req.Test.json(conn, %{"kind" => "storage#object", "name" => "path/to/file.txt"})
    end)

    assert {:ok, %{status: 200, body: %{"name" => "path/to/file.txt"}}} =
             ReqGCS.get_object(new_req(__MODULE__.GetObject), "my-bucket", "path/to/file.txt",
               auth: {:bearer, "t"}
             )
  end

  test "download_object sends GET with alt=media" do
    Req.Test.stub(__MODULE__.DownloadObject, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/storage/v1/b/my-bucket/o/hello.txt"

      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["alt"] == "media"

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(200, "Hello, world!")
    end)

    assert {:ok, %{status: 200, body: "Hello, world!"}} =
             ReqGCS.download_object(
               new_req(__MODULE__.DownloadObject),
               "my-bucket",
               "hello.txt",
               auth: {:bearer, "t"}
             )
  end

  test "upload_object sends POST to upload URL with uploadType=media" do
    Req.Test.stub(__MODULE__.UploadObject, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/upload/storage/v1/b/my-bucket/o"

      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["uploadType"] == "media"
      assert conn.query_params["name"] == "hello.txt"

      [content_type] = Plug.Conn.get_req_header(conn, "content-type")
      assert content_type == "text/plain"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == "Hello, world!"

      Req.Test.json(conn, %{"kind" => "storage#object", "name" => "hello.txt"})
    end)

    assert {:ok, %{status: 200, body: %{"name" => "hello.txt"}}} =
             ReqGCS.upload_object(
               new_req(__MODULE__.UploadObject),
               "my-bucket",
               "hello.txt",
               "Hello, world!",
               content_type: "text/plain",
               auth: {:bearer, "t"}
             )
  end

  test "delete_object sends DELETE /storage/v1/b/{bucket}/o/{object}" do
    Req.Test.stub(__MODULE__.DeleteObject, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/storage/v1/b/my-bucket/o/hello.txt"

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{status: 204}} =
             ReqGCS.delete_object(
               new_req(__MODULE__.DeleteObject),
               "my-bucket",
               "hello.txt",
               auth: {:bearer, "t"}
             )
  end

  test "copy_object sends POST to copyTo URL" do
    Req.Test.stub(__MODULE__.CopyObject, fn conn ->
      assert conn.method == "POST"

      assert conn.request_path ==
               "/storage/v1/b/src-bucket/o/src%2Fobj.txt/copyTo/b/dest-bucket/o/dest%2Fobj.txt"

      Req.Test.json(conn, %{"kind" => "storage#object", "name" => "dest/obj.txt"})
    end)

    assert {:ok, %{status: 200}} =
             ReqGCS.copy_object(
               new_req(__MODULE__.CopyObject),
               "src-bucket",
               "src/obj.txt",
               "dest-bucket",
               "dest/obj.txt",
               auth: {:bearer, "t"}
             )
  end

  test "compose_objects sends POST to compose URL with JSON body" do
    Req.Test.stub(__MODULE__.ComposeObjects, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/storage/v1/b/my-bucket/o/combined.txt/compose"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert length(decoded["sourceObjects"]) == 2

      Req.Test.json(conn, %{"kind" => "storage#object", "name" => "combined.txt"})
    end)

    assert {:ok, %{status: 200}} =
             ReqGCS.compose_objects(
               new_req(__MODULE__.ComposeObjects),
               "my-bucket",
               "combined.txt",
               [%{"name" => "part1.txt"}, %{"name" => "part2.txt"}],
               auth: {:bearer, "t"}
             )
  end
end
