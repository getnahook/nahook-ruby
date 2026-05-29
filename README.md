# Nahook Ruby SDK

Official Ruby SDK for the [Nahook](https://nahook.com) webhook platform. Send webhooks, fan-out by event type, and manage resources programmatically.

## Installation

Add to your Gemfile:

```ruby
gem "nahook"
```

Or install directly:

```bash
gem install nahook
```

**Requirements:** Ruby 3.0+

## Quick Start

### Sending Webhooks (Client)

```ruby
require "nahook"

client = Nahook::Client.new("nhk_us_your_api_key")

# Send to a specific endpoint
result = client.send("ep_abc123", payload: { order_id: "12345", status: "paid" })
puts result["deliveryId"] # => "del_..."

# Fan-out by event type (delivers to all subscribed endpoints)
result = client.trigger("order.paid", payload: { order_id: "12345" })
puts result["deliveryIds"] # => ["del_1", "del_2"]

# With metadata
client.trigger("order.paid",
  payload: { order_id: "12345" },
  metadata: { "source" => "checkout" }
)
```

### Managing Resources (Management)

```ruby
mgmt = Nahook::Management.new("nhm_your_management_token")

# Endpoints
endpoints = mgmt.endpoints.list("ws_abc123")
endpoint  = mgmt.endpoints.create("ws_abc123",
  url: "https://example.com/webhook",
  type: "webhook",
  description: "Production webhook"
)
mgmt.endpoints.update("ws_abc123", endpoint["id"], is_active: false)
mgmt.endpoints.delete("ws_abc123", endpoint["id"])

# Event Types
mgmt.event_types.create("ws_abc123", name: "order.paid", description: "Fired when an order is paid")
types = mgmt.event_types.list("ws_abc123")

# Applications
app = mgmt.applications.create("ws_abc123", name: "Acme Corp", external_id: "acme_123")
mgmt.applications.list("ws_abc123", limit: 10, offset: 0)
mgmt.applications.list_endpoints("ws_abc123", app["id"])
mgmt.applications.create_endpoint("ws_abc123", app["id"], url: "https://acme.com/hook")

# Subscriptions
mgmt.subscriptions.create("ws_abc123", "ep_def456", event_type_ids: ["evt_ghi789"])
mgmt.subscriptions.list("ws_abc123", "ep_def456")
mgmt.subscriptions.delete("ws_abc123", "ep_def456", "evt_ghi789")

# Environments
env = mgmt.environments.create("ws_abc123", name: "Staging", slug: "staging")
mgmt.environments.list("ws_abc123")
mgmt.environments.get("ws_abc123", env["id"])
mgmt.environments.update("ws_abc123", env["id"], name: "Pre-production")
mgmt.environments.delete("ws_abc123", env["id"])

# Event Type Visibility
mgmt.environments.list_event_type_visibility("ws_abc123", "env_abc123")
mgmt.environments.set_event_type_visibility("ws_abc123", "env_abc123", "evt_abc123", published: true)

# Portal Sessions
session = mgmt.portal_sessions.create("ws_abc123", "app_jkl012")
puts session["url"] # Redirect your customer here
```

### Deliveries

Read access to a workspace's webhook deliveries. There is no create/update/delete on this resource — deliveries are produced by the ingestion path and observed through these methods.

```ruby
# List deliveries for an endpoint, newest-first, cursor-paginated.
# `next_cursor` is OPAQUE — pass it back verbatim to fetch the next page.
page = mgmt.deliveries.list("ws_abc123", "ep_def456", limit: 50)
page.data.each { |d| puts "#{d['id']} #{d['status']}" }

while page.next_cursor
  page = mgmt.deliveries.list("ws_abc123", "ep_def456", cursor: page.next_cursor)
  page.data.each { |d| puts "#{d['id']} #{d['status']}" }
end

# Filter by status. Valid values: "pending", "delivering", "delivered",
# "scheduled_retry", "failed", "dead_letter".
failed = mgmt.deliveries.list("ws_abc123", "ep_def456", status: "failed")

# Fetch a single delivery (metadata only).
delivery = mgmt.deliveries.get("ws_abc123", "del_xyz")
puts delivery["status"]         # => "delivered"
puts delivery["totalAttempts"]  # => 1
puts delivery["hasPayload"]     # => true

# Fetch with the payload envelope. The envelope is a tagged hash whose
# "status" is one of: "available", "forbidden", "processing", "not_found",
# "error". The endpoint stays HTTP 200 for all 5 -- the envelope status
# carries access-level reality, so do NOT rescue on the non-"available" ones.
delivery = mgmt.deliveries.get("ws_abc123", "del_xyz", include_payload: true)
case delivery["payload"]["status"]
when "available"
  body         = delivery["payload"]["data"]          # decoded JSON
  content_type = delivery["payload"]["contentType"]   # "application/json"
when "forbidden"
  # Workspace plan does not include payload storage.
when "processing"
  # Delivery still in flight; payload may be racing the read.
when "not_found"
  # Terminal delivery without stored payload (older row, or plan was lower at ingest).
when "error"
  # Transient infrastructure failure -- safe to retry.
end

# List attempts for a delivery in chronological order (oldest first).
# The attempt "status" is an opaque string, not an enum.
attempts = mgmt.deliveries.get_attempts("ws_abc123", "del_xyz")
attempts.each { |a| puts "##{a['attemptNumber']} #{a['status']} #{a['responseStatusCode']}" }
```

## Client Options

### Nahook::Client

```ruby
client = Nahook::Client.new("nhk_us_...",
  timeout_ms: 30_000,                   # milliseconds, default
  retries: 3                            # retry on 5xx/429/network errors
)
```

### Configuration

The SDK automatically routes requests to the correct regional API based on your API key prefix (`nhk_us_...` -> US, `nhk_eu_...` -> EU, `nhk_ap_...` -> Asia Pacific). No configuration needed.

To override the base URL (for testing or local development):

```ruby
client = Nahook::Client.new("nhk_us_...", base_url: "http://localhost:3001")
```

For unit tests, mock the SDK client at the dependency injection boundary. For integration tests, override the base URL to point at a local server.

### Nahook::Management

```ruby
mgmt = Nahook::Management.new("nhm_...",
  timeout_ms: 30_000                    # milliseconds, default
)
# Note: Management does not support retries
```

## Batch Operations

```ruby
# Send to multiple endpoints (max 20)
result = client.send_batch([
  { endpoint_id: "ep_abc", payload: { order: 1 } },
  { endpoint_id: "ep_def", payload: { order: 2 }, idempotency_key: "key-2" }
])

# Fan-out multiple event types (max 20)
result = client.trigger_batch([
  { event_type: "order.paid", payload: { order_id: "123" } },
  { event_type: "user.created", payload: { user_id: "456" }, metadata: { "source" => "api" } }
])
```

## Idempotency

The `send` method auto-generates a UUID idempotency key if you don't provide one:

```ruby
# Auto-generated idempotency key
client.send("ep_abc", payload: { order: 1 })

# Explicit idempotency key
client.send("ep_abc", payload: { order: 1 }, idempotency_key: "order-1-v1")
```

## Error Handling

```ruby
begin
  client.send("ep_abc", payload: { test: true })
rescue Nahook::APIError => e
  puts e.message       # Human-readable message
  puts e.status        # HTTP status code
  puts e.code          # Machine-readable error code
  puts e.retryable?    # true for 5xx and 429
  puts e.auth_error?   # true for 401, or 403 with token_disabled
  puts e.not_found?    # true for 404
  puts e.rate_limited? # true for 429
  puts e.retry_after   # Retry-After header value (seconds), if present
rescue Nahook::NetworkError => e
  puts e.message       # "Network error: ..."
  puts e.original_error # Original exception
rescue Nahook::TimeoutError => e
  puts e.message       # "Request timed out after 30000ms"
  puts e.timeout_ms    # Timeout in milliseconds
rescue Nahook::Error => e
  # Catch-all for any SDK error
end
```

## Retry Logic

When `retries` is configured on `Nahook::Client`, the SDK automatically retries on:

- HTTP 5xx responses
- HTTP 429 (rate limited) -- respects `Retry-After` header
- Network connection failures
- Request timeouts

Retry delay uses exponential backoff with full jitter (base 500ms, max 10s).

## License

MIT
