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

client = Nahook::Client.new("nhk_your_api_key")

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
mgmt.subscriptions.create("ws_abc123", "ep_def456", event_type_id: "evt_ghi789")
mgmt.subscriptions.list("ws_abc123", "ep_def456")
mgmt.subscriptions.delete("ws_abc123", "ep_def456", "evt_ghi789")

# Portal Sessions
session = mgmt.portal_sessions.create("ws_abc123", "app_jkl012")
puts session["url"] # Redirect your customer here
```

## Client Options

### Nahook::Client

```ruby
client = Nahook::Client.new("nhk_...",
  base_url: "https://api.nahook.com",  # default
  timeout: 30,                          # seconds, default
  retries: 3                            # retry on 5xx/429/network errors
)
```

### Nahook::Management

```ruby
mgmt = Nahook::Management.new("nhm_...",
  base_url: "https://api.nahook.com",  # default
  timeout: 30                           # seconds, default
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
  puts e.cause         # Original exception
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
