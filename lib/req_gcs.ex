defmodule ReqGCS do
  @moduledoc """
  A Req plugin for Google Cloud Storage.

  ## Usage

      # With a named Goth process (cached tokens):
      req = Req.new() |> ReqGCS.attach(gcs_goth: MyApp.Goth, gcs_project: "my-project")

      # With inline credentials (stateless):
      creds = Jason.decode!(stored_json_key)
      req = Req.new() |> ReqGCS.attach(gcs_credentials: creds, gcs_project: "my-project")

      # Via application config:
      # config :req_gcs, credentials: Jason.decode!(File.read!("service-account.json"))
      req = Req.new() |> ReqGCS.attach(gcs_project: "my-project")

      # Then use convenience functions:
      {:ok, resp} = ReqGCS.list_buckets(req)
      {:ok, resp} = ReqGCS.upload_object(req, "my-bucket", "path/to/file.txt", "hello")
  """

  @base_url "https://storage.googleapis.com/storage/v1"
  @upload_url "https://storage.googleapis.com/upload/storage/v1"

  @doc """
  Attaches the ReqGCS plugin to a `Req.Request`.

  ## Options

    * `:gcs_goth` - name of a running Goth process for cached token fetching
    * `:gcs_credentials` - a parsed service account JSON map for stateless token fetching
    * `:gcs_project` - the GCP project ID (required for bucket creation and listing)
  """
  def attach(%Req.Request{} = request, options \\ []) do
    request
    |> Req.Request.register_options([:gcs_credentials, :gcs_goth, :gcs_project])
    |> Req.Request.merge_options(options)
    |> Req.Request.prepend_request_steps(gcs_auth: &gcs_auth_step/1)
  end

  # --- Bucket Operations ---

  @doc """
  Lists buckets for the configured project.

  Requires `:gcs_project` to be set on attach or passed as `project:` in opts.
  """
  def list_buckets(request, opts \\ []) do
    {project, opts} = pop_project!(request, opts)
    {extra_params, opts} = Keyword.pop(opts, :params, [])

    request!(request, [
      {:method, :get},
      {:url, "#{@base_url}/b"},
      {:params, [{:project, project} | extra_params]}
      | opts
    ])
  end

  @doc "Gets a bucket's metadata."
  def get_bucket(request, bucket, opts \\ []) do
    request!(request, [{:method, :get}, {:url, "#{@base_url}/b/#{bucket}"} | opts])
  end

  @doc """
  Creates a new bucket.

  `bucket_resource` is a map representing the bucket, e.g. `%{"name" => "my-bucket"}`.
  Requires `:gcs_project` to be set on attach or passed as `project:` in opts.
  """
  def create_bucket(request, bucket_resource, opts \\ []) when is_map(bucket_resource) do
    {project, opts} = pop_project!(request, opts)
    {extra_params, opts} = Keyword.pop(opts, :params, [])

    request!(request, [
      {:method, :post},
      {:url, "#{@base_url}/b"},
      {:params, [{:project, project} | extra_params]},
      {:json, bucket_resource}
      | opts
    ])
  end

  @doc """
  Updates (patches) a bucket's metadata.

  `bucket_resource` is a map of fields to update.
  """
  def update_bucket(request, bucket, bucket_resource, opts \\ [])
      when is_map(bucket_resource) do
    request!(
      request,
      [{:method, :patch}, {:url, "#{@base_url}/b/#{bucket}"}, {:json, bucket_resource} | opts]
    )
  end

  @doc "Deletes a bucket."
  def delete_bucket(request, bucket, opts \\ []) do
    request!(request, [{:method, :delete}, {:url, "#{@base_url}/b/#{bucket}"} | opts])
  end

  # --- Object Operations ---

  @doc """
  Lists objects in a bucket.

  ## Options

    * `:prefix` - filter results to objects whose names begin with this prefix
    * `:delimiter` - used to group results (commonly `"/"`)
    * `:max_results` - maximum number of items to return
    * `:page_token` - page token from a previous response for pagination
  """
  def list_objects(request, bucket, opts \\ []) do
    {list_params, opts} = pop_list_params(opts)
    {extra_params, opts} = Keyword.pop(opts, :params, [])

    request!(request, [
      {:method, :get},
      {:url, "#{@base_url}/b/#{bucket}/o"},
      {:params, list_params ++ extra_params}
      | opts
    ])
  end

  @doc "Gets an object's metadata."
  def get_object(request, bucket, object, opts \\ []) do
    request!(
      request,
      [{:method, :get}, {:url, object_url(bucket, object)} | opts]
    )
  end

  @doc """
  Downloads an object's content (returns raw bytes in the response body).
  """
  def download_object(request, bucket, object, opts \\ []) do
    {extra_params, opts} = Keyword.pop(opts, :params, [])

    request!(request, [
      {:method, :get},
      {:url, object_url(bucket, object)},
      {:params, [{:alt, "media"} | extra_params]},
      {:decode_body, false}
      | opts
    ])
  end

  @doc """
  Uploads an object using a simple media upload. Uploading to the same name overwrites
  the existing object (i.e., this also serves as "replace").

  ## Options

    * `:content_type` - the content type of the object (defaults to `"application/octet-stream"`)
  """
  def upload_object(request, bucket, name, body, opts \\ []) do
    {content_type, opts} = Keyword.pop(opts, :content_type, "application/octet-stream")
    {extra_params, opts} = Keyword.pop(opts, :params, [])

    request!(request, [
      {:method, :post},
      {:url, "#{@upload_url}/b/#{bucket}/o"},
      {:params, [{:uploadType, "media"}, {:name, name} | extra_params]},
      {:headers, [{"content-type", content_type}]},
      {:body, body}
      | opts
    ])
  end

  @doc "Deletes an object."
  def delete_object(request, bucket, object, opts \\ []) do
    request!(
      request,
      [{:method, :delete}, {:url, object_url(bucket, object)} | opts]
    )
  end

  @doc "Copies an object from one location to another."
  def copy_object(request, src_bucket, src_object, dest_bucket, dest_object, opts \\ []) do
    url =
      "#{@base_url}/b/#{src_bucket}/o/#{encode_object(src_object)}" <>
        "/copyTo/b/#{dest_bucket}/o/#{encode_object(dest_object)}"

    request!(request, [{:method, :post}, {:url, url} | opts])
  end

  @doc """
  Composes multiple objects into a single destination object.

  `source_objects` is a list of maps, e.g.:

      [%{"name" => "part1.txt"}, %{"name" => "part2.txt"}]
  """
  def compose_objects(request, bucket, dest_object, source_objects, opts \\ [])
      when is_list(source_objects) do
    request!(
      request,
      [
        {:method, :post},
        {:url, "#{object_url(bucket, dest_object)}/compose"},
        {:json, %{"sourceObjects" => source_objects}} | opts
      ]
    )
  end

  # --- Private Helpers ---

  defp gcs_auth_step(%Req.Request{} = request) do
    if gcs_request?(request) and is_nil(request.options[:auth]) do
      case ReqGCS.Auth.fetch_token(request.options) do
        {:ok, %{token: token}} ->
          Req.Request.merge_options(request, auth: {:bearer, token})

        {:error, exception} ->
          Req.Request.halt(request, exception)
      end
    else
      request
    end
  end

  defp gcs_request?(%Req.Request{url: %URI{host: "storage.googleapis.com"}}), do: true
  defp gcs_request?(%Req.Request{url: %URI{host: nil}}), do: true
  defp gcs_request?(_), do: false

  defp request!(request, opts) do
    Req.request(request, opts)
  end

  defp object_url(bucket, object) do
    "#{@base_url}/b/#{bucket}/o/#{encode_object(object)}"
  end

  defp encode_object(object) do
    URI.encode(object, &URI.char_unreserved?/1)
  end

  defp pop_project!(request, opts) do
    case Keyword.pop(opts, :project) do
      {nil, opts} ->
        case request.options[:gcs_project] do
          nil ->
            raise ArgumentError,
                  "GCS project is required. Pass project: option or set :gcs_project on attach."

          project ->
            {project, opts}
        end

      {project, opts} ->
        {project, opts}
    end
  end

  defp pop_list_params(opts) do
    {prefix, opts} = Keyword.pop(opts, :prefix)
    {delimiter, opts} = Keyword.pop(opts, :delimiter)
    {max_results, opts} = Keyword.pop(opts, :max_results)
    {page_token, opts} = Keyword.pop(opts, :page_token)

    params =
      [prefix: prefix, delimiter: delimiter, maxResults: max_results, pageToken: page_token]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    {params, opts}
  end
end
