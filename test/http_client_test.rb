# frozen_string_literal: true

require "minitest/autorun"
require "faraday"
require "nahook"

class HttpClientTest < Minitest::Test
  API_KEY = "nhk_us_testapikey"

  # ── Default adapter (Pass 1: keep-alive) ────────────────────────────────

  def test_default_adapter_is_net_http_persistent
    client = Nahook::Client.new(API_KEY)
    conn = client.instance_variable_get(:@http).instance_variable_get(:@conn)

    handler = conn.adapter
    # Faraday 2 exposes the adapter as a class on the builder. The actual
    # class lives in faraday/net_http_persistent.
    assert_includes handler.name, "NetHttpPersistent",
                    "expected default adapter to be NetHttpPersistent, got #{handler.name}"
  end

  def test_default_adapter_constant
    assert_equal :net_http_persistent, Nahook::HttpClient::DEFAULT_ADAPTER
  end

  # ── BYO adapter (Pass 2: adapter: kwarg) ────────────────────────────────

  def test_adapter_kwarg_swaps_the_default
    # :test is always available — Faraday ships it for stubbing in tests.
    client = Nahook::Client.new(API_KEY, adapter: :test)
    conn = client.instance_variable_get(:@http).instance_variable_get(:@conn)

    assert_includes conn.adapter.name, "Test",
                    "expected :test adapter, got #{conn.adapter.name}"
  end

  def test_adapter_kwarg_works_for_management
    mgmt = Nahook::Management.new("nhm_token", adapter: :test)
    # Management does not expose @http publicly — reach in via resources.
    http = mgmt.endpoints.instance_variable_get(:@http)
    conn = http.instance_variable_get(:@conn)

    assert_includes conn.adapter.name, "Test"
  end

  # ── BYO connection (Pass 2: connection: kwarg) ──────────────────────────

  def test_connection_kwarg_uses_supplied_connection_verbatim
    custom = Faraday.new(url: "https://custom.example.com") do |f|
      f.options.timeout = 7
      f.adapter :test
    end

    client = Nahook::Client.new(API_KEY, connection: custom)
    conn = client.instance_variable_get(:@http).instance_variable_get(:@conn)

    assert_same custom, conn, "expected the SDK to use the supplied connection verbatim"
  end

  def test_connection_kwarg_ignores_base_url_and_adapter
    # If `connection:` won precedence, the supplied URL — not base_url — sticks.
    custom = Faraday.new(url: "https://custom.example.com") do |f|
      f.adapter :test
    end

    client = Nahook::Client.new(
      API_KEY,
      base_url: "https://overridden.example.com",
      adapter:  :net_http,
      connection: custom,
    )
    conn = client.instance_variable_get(:@http).instance_variable_get(:@conn)

    assert_equal URI("https://custom.example.com"), conn.url_prefix
    assert_includes conn.adapter.name, "Test"
  end

  def test_connection_kwarg_timeout_takes_precedence_for_error_reporting
    # Caller set the connection's timeout to 7 s; SDK kwarg defaulted to 30 s.
    # When a TimeoutError is reported, it should reflect the connection's value
    # (7000 ms), not the SDK kwarg default.
    custom = Faraday.new(url: "https://x.example") do |f|
      f.options.timeout = 7
      f.adapter :test
    end

    client = Nahook::Client.new(API_KEY, connection: custom)
    http = client.instance_variable_get(:@http)

    assert_equal 7000, http.instance_variable_get(:@timeout_ms)
  end

  def test_connection_kwarg_falls_back_to_timeout_ms_when_unset
    # No timeout configured on the custom connection — fall back to the kwarg.
    custom = Faraday.new(url: "https://x.example") { |f| f.adapter :test }

    client = Nahook::Client.new(API_KEY, timeout_ms: 12_345, connection: custom)
    http = client.instance_variable_get(:@http)

    assert_equal 12_345, http.instance_variable_get(:@timeout_ms)
  end

  def test_connection_kwarg_takes_precedence_over_adapter_kwarg
    # If both are supplied, `connection:` wins (uses the conn verbatim).
    custom = Faraday.new(url: "https://x.example") do |f|
      f.adapter :test
    end

    client = Nahook::Client.new(API_KEY, adapter: :typhoeus, connection: custom)
    conn = client.instance_variable_get(:@http).instance_variable_get(:@conn)

    assert_same custom, conn
    # And the adapter is still :test from the custom connection, not :typhoeus.
    assert_includes conn.adapter.name, "Test"
  end

  # ── Connection reuse (Pass 1 acceptance criterion) ──────────────────────

  def test_persistent_adapter_reuses_connection_across_requests
    # Counter adapter: increments on every request. Multiple SDK calls go
    # through the SAME Faraday connection instance — proves the SDK reuses
    # @conn across calls instead of building a new one per request (which
    # would also build a new adapter, which would reset the counter).
    request_count = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(/api\/ingest\/.*/) do |env|
        request_count += 1
        [202, { "Content-Type" => "application/json" },
         JSON.generate({ deliveryId: "del_#{request_count}",
                         idempotencyKey: "key-#{request_count}",
                         status: "accepted" })]
      end
    end

    custom = Faraday.new(url: "https://x.example") do |f|
      f.adapter :test, stubs
    end

    client = Nahook::Client.new(API_KEY, connection: custom)

    5.times { |i| client.send("ep_abc", payload: { i: i }) }

    assert_equal 5, request_count
    # The Faraday connection is the same object across calls — the SDK is
    # not reconstructing it per request.
    http = client.instance_variable_get(:@http)
    assert_same custom, http.instance_variable_get(:@conn)
  end
end
