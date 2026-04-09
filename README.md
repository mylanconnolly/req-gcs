# ReqGCS

A [Req](https://hexdocs.pm/req) plugin for [Google Cloud Storage](https://cloud.google.com/storage).

Provides an ergonomic API for bucket and object operations, with flexible
authentication via [Goth](https://hexdocs.pm/goth).

## Installation

Add `req_gcs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:req_gcs, "~> 0.1.0"}
  ]
end
```

## Authentication

ReqGCS supports three ways to authenticate, checked in this order:

### 1. Named Goth process (recommended for production)

Start a [Goth](https://hexdocs.pm/goth) process in your application's supervision
tree. Tokens are cached in ETS and auto-refreshed before expiry.

```elixir
# In your Application.start/2:
credentials = "service-account.json" |> File.read!() |> Jason.decode!()

children = [
  {Goth, name: MyApp.Goth, source: {:service_account, credentials}}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Then pass the process name when attaching:

```elixir
req = Req.new() |> ReqGCS.attach(gcs_goth: MyApp.Goth, gcs_project: "my-project")
```

### 2. Inline credentials (per-request)

Pass a parsed service account JSON map directly. Useful when credentials are
stored in a database or vary per tenant. ReqGCS automatically starts a managed
Goth process for each unique credential set, so tokens are cached in ETS and
auto-refreshed — no per-request OAuth round-trips.

```elixir
credentials = Jason.decode!(stored_json_key)
req = Req.new() |> ReqGCS.attach(gcs_credentials: credentials, gcs_project: "my-project")
```

Managed Goth processes that haven't been used in over an hour are automatically
stopped by a background sweeper to prevent unbounded memory growth.

### 3. Application config (fallback)

Set credentials in your app config:

```elixir
config :req_gcs, credentials: Jason.decode!(File.read!("service-account.json"))
```

Then attach without explicit credentials:

```elixir
req = Req.new() |> ReqGCS.attach(gcs_project: "my-project")
```

This path also benefits from automatic token caching (same as inline credentials).

## Usage

All convenience functions return `{:ok, %Req.Response{}}` or `{:error, exception}`.
Every function accepts trailing opts that are passed through to `Req.request/2`,
so you can use any Req option (`:headers`, `:params`, etc.).

### Setup

```elixir
req = Req.new() |> ReqGCS.attach(gcs_goth: MyApp.Goth, gcs_project: "my-project")
```

You can also use the `plugins` option:

```elixir
req = Req.new(plugins: [ReqGCS], gcs_goth: MyApp.Goth, gcs_project: "my-project")
```

### Buckets

```elixir
# List buckets
{:ok, resp} = ReqGCS.list_buckets(req)

# Get bucket metadata
{:ok, resp} = ReqGCS.get_bucket(req, "my-bucket")

# Create a bucket
{:ok, resp} = ReqGCS.create_bucket(req, %{"name" => "my-new-bucket"})

# Update bucket metadata
{:ok, resp} = ReqGCS.update_bucket(req, "my-bucket", %{"versioning" => %{"enabled" => true}})

# Delete a bucket
{:ok, resp} = ReqGCS.delete_bucket(req, "my-bucket")
```

### Objects

```elixir
# List objects
{:ok, resp} = ReqGCS.list_objects(req, "my-bucket")

# List with prefix/delimiter for "directory" listing
{:ok, resp} = ReqGCS.list_objects(req, "my-bucket", prefix: "logs/", delimiter: "/")

# Pagination
{:ok, resp} = ReqGCS.list_objects(req, "my-bucket", max_results: 100, page_token: token)

# Get object metadata
{:ok, resp} = ReqGCS.get_object(req, "my-bucket", "path/to/file.txt")

# Download object content
{:ok, resp} = ReqGCS.download_object(req, "my-bucket", "path/to/file.txt")
resp.body  # => raw bytes

# Upload an object
{:ok, resp} = ReqGCS.upload_object(req, "my-bucket", "hello.txt", "Hello, world!",
  content_type: "text/plain"
)

# Replace an object (upload with the same name overwrites)
{:ok, resp} = ReqGCS.upload_object(req, "my-bucket", "hello.txt", "Updated content")

# Delete an object
{:ok, resp} = ReqGCS.delete_object(req, "my-bucket", "hello.txt")

# Copy an object
{:ok, resp} = ReqGCS.copy_object(req, "src-bucket", "src.txt", "dest-bucket", "dest.txt")

# Compose multiple objects into one
{:ok, resp} = ReqGCS.compose_objects(req, "my-bucket", "combined.txt", [
  %{"name" => "part1.txt"},
  %{"name" => "part2.txt"}
])
```

## Testing

The auth step is skipped when `:auth` is already set on the request, so you can
use `Req.Test` stubs without real credentials:

```elixir
Req.Test.stub(MyStub, fn conn ->
  Req.Test.json(conn, %{"kind" => "storage#objects", "items" => []})
end)

req =
  Req.new(plug: {Req.Test, MyStub})
  |> ReqGCS.attach(gcs_project: "test-project")

{:ok, resp} = ReqGCS.list_objects(req, "my-bucket", auth: {:bearer, "fake-token"})
```

## Configuration

Optional settings with sensible defaults:

```elixir
config :req_gcs,
  sweep_interval: 300_000,   # how often to check for idle processes (default: 5 min)
  max_idle: 3_600_000        # idle time before a managed Goth process is stopped (default: 1 hour)
```

## License

See [LICENSE](LICENSE) for details.
