# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "nahook"

class ClientTest < Minitest::Test
  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    @api_key = "nhk_us_testapikey"
  end

  def build_client(api_key: @api_key)
    client = Nahook::Client.new(api_key, base_url: "https://api.test.com")
    http = client.instance_variable_get(:@http)
    conn = http.instance_variable_get(:@conn)
    new_conn = Faraday.new(url: conn.url_prefix) do |f|
      f.options.timeout = conn.options.timeout
      f.adapter :test, @stubs
    end
    http.instance_variable_set(:@conn, new_conn)
    client
  end

  # -- Key validation -------------------------------------------------------

  def test_rejects_invalid_api_key_prefix
    assert_raises(ArgumentError) { Nahook::Client.new("bad_key") }
  end

  def test_accepts_valid_nhk_api_key
    client = Nahook::Client.new("nhk_us_valid")
    refute_nil client
  end

  # -- Endpoint routing -----------------------------------------------------

  def test_send_calls_correct_endpoint
    @stubs.post("/api/ingest/ep_abc") do |env|
      body = JSON.parse(env.body)
      assert_equal({ "order" => 1 }, body["payload"])
      assert body.key?("idempotencyKey")
      [202, { "Content-Type" => "application/json" }, JSON.generate({ "deliveryId" => "del_1", "status" => "accepted" })]
    end

    client = build_client
    result = client.send("ep_abc", payload: { "order" => 1 })
    assert_equal "del_1", result["deliveryId"]
    @stubs.verify_stubbed_calls
  end

  def test_trigger_calls_correct_endpoint
    @stubs.post("/api/ingest/event/order.paid") do |env|
      body = JSON.parse(env.body)
      assert_equal({ "id" => "123" }, body["payload"])
      [202, { "Content-Type" => "application/json" }, JSON.generate({ "eventTypeId" => "evt_1", "deliveryIds" => ["del_1"] })]
    end

    client = build_client
    result = client.trigger("order.paid", payload: { "id" => "123" })
    assert_equal "evt_1", result["eventTypeId"]
    @stubs.verify_stubbed_calls
  end

  def test_send_batch_calls_correct_endpoint
    @stubs.post("/api/ingest/batch") do |env|
      body = JSON.parse(env.body)
      assert_equal 2, body["items"].length
      assert_equal "ep_a", body["items"][0]["endpointId"]
      assert_equal "ep_b", body["items"][1]["endpointId"]
      [202, { "Content-Type" => "application/json" }, JSON.generate({ "items" => [{ "status" => "accepted" }, { "status" => "accepted" }] })]
    end

    client = build_client
    result = client.send_batch([
      { endpoint_id: "ep_a", payload: { "x" => 1 } },
      { endpoint_id: "ep_b", payload: { "x" => 2 } }
    ])
    assert_equal 2, result["items"].length
    @stubs.verify_stubbed_calls
  end

  def test_trigger_batch_calls_correct_endpoint
    @stubs.post("/api/ingest/event/batch") do |env|
      body = JSON.parse(env.body)
      assert_equal 2, body["items"].length
      assert_equal "order.paid", body["items"][0]["eventType"]
      assert_equal "user.created", body["items"][1]["eventType"]
      [202, { "Content-Type" => "application/json" }, JSON.generate({ "items" => [{ "status" => "accepted" }, { "status" => "accepted" }] })]
    end

    client = build_client
    result = client.trigger_batch([
      { event_type: "order.paid", payload: { "a" => 1 } },
      { event_type: "user.created", payload: { "b" => 2 } }
    ])
    assert_equal 2, result["items"].length
    @stubs.verify_stubbed_calls
  end

  # -- Error handling -------------------------------------------------------

  def test_raises_api_error_on_error_response
    @stubs.post("/api/ingest/ep_bad") do
      [400, { "Content-Type" => "application/json" }, JSON.generate({ "error" => { "code" => "validation_error", "message" => "Invalid payload" } })]
    end

    client = build_client
    error = assert_raises(Nahook::APIError) { client.send("ep_bad", payload: {}) }
    assert_equal 400, error.status
    assert_equal "validation_error", error.code
    @stubs.verify_stubbed_calls
  end
end
