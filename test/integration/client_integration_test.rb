# frozen_string_literal: true

require "minitest/autorun"
require "securerandom"
require "nahook"

class ClientIntegrationTest < Minitest::Test
  def setup
    @api_url      = ENV["NAHOOK_TEST_API_URL"]
    @api_key      = ENV["NAHOOK_TEST_API_KEY"]
    @disabled_key = ENV["NAHOOK_TEST_DISABLED_API_KEY"]
    @endpoint_id  = ENV["NAHOOK_TEST_ENDPOINT_ID"]
    @event_type   = ENV["NAHOOK_TEST_EVENT_TYPE"]

    unless @api_url && @api_key && @disabled_key && @endpoint_id && @event_type
      skip "integration env not set"
    end

    @client = Nahook::Client.new(@api_key, base_url: @api_url)
  end

  # -- send ----------------------------------------------------------------

  def test_send_happy_path
    result = @client.send(@endpoint_id, payload: { "test" => true, "ts" => Time.now.to_i })

    assert_equal "accepted", result["status"]
    assert_match(/^del_/, result["deliveryId"])
  end

  def test_send_idempotency_dedup
    key = "idem-ruby-#{SecureRandom.hex(8)}"

    r1 = @client.send(@endpoint_id, payload: { "dedup" => 1 }, idempotency_key: key)
    r2 = @client.send(@endpoint_id, payload: { "dedup" => 1 }, idempotency_key: key)

    assert_equal r1["deliveryId"], r2["deliveryId"]
  end

  def test_send_separate_keys
    r1 = @client.send(@endpoint_id, payload: { "k" => 1 }, idempotency_key: "sep-ruby-#{SecureRandom.hex(8)}")
    r2 = @client.send(@endpoint_id, payload: { "k" => 2 }, idempotency_key: "sep-ruby-#{SecureRandom.hex(8)}")

    refute_equal r1["deliveryId"], r2["deliveryId"]
  end

  # -- trigger -------------------------------------------------------------

  def test_trigger_fan_out
    result = @client.trigger(@event_type, payload: { "fan" => "out", "ts" => Time.now.to_i })

    assert_equal "accepted", result["status"]
    assert_match(/^evt_/, result["eventTypeId"])
    assert_kind_of Array, result["deliveryIds"]
    assert result["deliveryIds"].length >= 1, "expected at least 1 delivery"
  end

  def test_trigger_unsubscribed
    result = @client.trigger("unsubscribed.event.type", payload: { "no" => "subscribers" })

    assert_kind_of Array, result["deliveryIds"]
    assert_empty result["deliveryIds"]
  end

  # -- batch ---------------------------------------------------------------

  def test_send_batch_accepted
    result = @client.send_batch([
      { endpoint_id: @endpoint_id, payload: { "batch" => 1 } },
      { endpoint_id: @endpoint_id, payload: { "batch" => 2 } }
    ])

    items = result["items"]
    assert_equal 2, items.length
    items.each do |item|
      assert_equal "accepted", item["status"]
      assert_match(/^del_/, item["deliveryId"])
    end
  end

  def test_trigger_batch_accepted
    result = @client.trigger_batch([
      { event_type: @event_type, payload: { "tb" => 1 } },
      { event_type: @event_type, payload: { "tb" => 2 } }
    ])

    items = result["items"]
    assert_equal 2, items.length
    items.each do |item|
      assert_equal "accepted", item["status"]
      assert_match(/^evt_/, item["eventTypeId"])
    end
  end

  # -- error cases ---------------------------------------------------------

  def test_error_401_invalid_key
    bad_client = Nahook::Client.new("nhk_us_totally_invalid_key", base_url: @api_url)

    err = assert_raises(Nahook::APIError) do
      bad_client.send(@endpoint_id, payload: { "should" => "fail" })
    end

    assert_equal 401, err.status
    assert err.auth_error?, "expected auth_error? to be true"
    refute err.retryable?, "expected retryable? to be false"
  end

  def test_error_403_disabled_key
    disabled_client = Nahook::Client.new(@disabled_key, base_url: @api_url)

    err = assert_raises(Nahook::APIError) do
      disabled_client.send(@endpoint_id, payload: { "should" => "fail" })
    end

    assert_equal 403, err.status
    assert_equal "token_disabled", err.code
  end

  def test_error_404_missing_endpoint
    err = assert_raises(Nahook::APIError) do
      @client.send("ep_nonexistent_endpoint_xyz", payload: { "should" => "fail" })
    end

    assert_equal 404, err.status
    assert err.not_found?, "expected not_found? to be true"
  end

  def test_error_400_invalid_event_type
    err = assert_raises(Nahook::APIError) do
      @client.trigger("!!!invalid event type!!!", payload: { "should" => "fail" })
    end

    assert_equal 400, err.status
    assert err.validation_error?, "expected validation_error? to be true"
  end
end
