# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "nahook"

# Negative / resilience tests driven by shared fixtures.
# Verifies the SDK handles malformed, empty, and unexpected API responses.
class NegativeTest < Minitest::Test
  FIXTURES_PATH = File.join(
    File.expand_path("../../fixtures/conformance", __dir__),
    "negative", "cases.json"
  )

  CASES = JSON.parse(File.read(FIXTURES_PATH))

  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    @token = "nhm_test_token"
  end

  def build_management
    mgmt = Nahook::Management.new(@token, base_url: "https://api.test.com")
    replace_adapter(mgmt)
    mgmt
  end

  # -- NEG-01: Malformed JSON on 200 ------------------------------------------

  def test_neg_01_malformed_json_response
    tc = CASES.find { |c| c["id"] == "NEG-01" }
    mock = tc["mockResponse"]

    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [mock["status"], { "Content-Type" => mock["contentType"] }, mock["body"]]
    end

    mgmt = build_management
    assert_raises(JSON::ParserError) { mgmt.endpoints.list("ws_1") }
    @stubs.verify_stubbed_calls
  end

  # -- NEG-02: Empty body on 200 ----------------------------------------------

  def test_neg_02_empty_body_on_200
    tc = CASES.find { |c| c["id"] == "NEG-02" }
    mock = tc["mockResponse"]

    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [mock["status"], { "Content-Type" => mock["contentType"] }, mock["body"]]
    end

    mgmt = build_management
    assert_raises(JSON::ParserError) { mgmt.endpoints.list("ws_1") }
    @stubs.verify_stubbed_calls
  end

  # -- NEG-03: 5xx with HTML body ----------------------------------------------

  def test_neg_03_5xx_with_html_body
    tc = CASES.find { |c| c["id"] == "NEG-03" }
    mock = tc["mockResponse"]

    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [mock["status"], { "Content-Type" => mock["contentType"] }, mock["body"]]
    end

    mgmt = build_management
    error = assert_raises(Nahook::APIError) { mgmt.endpoints.list("ws_1") }
    assert_equal tc["expect"]["status"], error.status
    assert error.retryable?, "NEG-03: should be retryable"
    @stubs.verify_stubbed_calls
  end

  # -- NEG-04: 5xx with empty body ---------------------------------------------

  def test_neg_04_5xx_with_empty_body
    tc = CASES.find { |c| c["id"] == "NEG-04" }
    mock = tc["mockResponse"]

    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [mock["status"], { "Content-Type" => mock["contentType"] }, mock["body"]]
    end

    mgmt = build_management
    error = assert_raises(Nahook::APIError) { mgmt.endpoints.list("ws_1") }
    assert_equal tc["expect"]["status"], error.status
    assert error.retryable?, "NEG-04: should be retryable"
    @stubs.verify_stubbed_calls
  end

  # -- NEG-05: Unknown extra fields handled gracefully -------------------------

  def test_neg_05_unknown_extra_fields
    tc = CASES.find { |c| c["id"] == "NEG-05" }
    mock = tc["mockResponse"]

    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [mock["status"], { "Content-Type" => mock["contentType"] }, mock["body"]]
    end

    mgmt = build_management
    result = mgmt.endpoints.list("ws_1")
    assert result["data"].length >= 1, "NEG-05: should have data"
    assert_equal "ep_1", result["data"][0]["id"]
    @stubs.verify_stubbed_calls
  end

  # -- NEG-06: Missing optional fields defaults gracefully ---------------------

  def test_neg_06_missing_optional_fields
    tc = CASES.find { |c| c["id"] == "NEG-06" }
    mock = tc["mockResponse"]

    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [mock["status"], { "Content-Type" => mock["contentType"] }, mock["body"]]
    end

    mgmt = build_management
    result = mgmt.endpoints.list("ws_1")
    assert result["data"].length >= 1, "NEG-06: should have data"
    assert_equal "ep_1", result["data"][0]["id"]
    # Missing field should just be nil, not crash
    assert_nil result["data"][0]["url"]
    @stubs.verify_stubbed_calls
  end

  private

  def replace_adapter(mgmt)
    [mgmt.endpoints, mgmt.event_types, mgmt.applications,
     mgmt.subscriptions, mgmt.portal_sessions, mgmt.environments].each do |resource|
      http = resource.instance_variable_get(:@http)
      conn = http.instance_variable_get(:@conn)
      new_conn = Faraday.new(url: conn.url_prefix) do |f|
        f.options.timeout = conn.options.timeout
        f.adapter :test, @stubs
      end
      http.instance_variable_set(:@conn, new_conn)
    end
  end
end
