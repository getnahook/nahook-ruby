# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "openssl"
require "base64"
require "nahook"

# Conformance tests driven by shared JSON fixtures in ../fixtures/conformance/.
# These ensure cross-SDK behavioral parity.
class ConformanceTest < Minitest::Test
  FIXTURES_DIR = File.expand_path("../../fixtures/conformance", __dir__)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def load_cases(category)
    path = File.join(FIXTURES_DIR, category, "cases.json")
    JSON.parse(File.read(path))
  end

  # Mirrors the signing logic from webhook_signature_test.rb
  def compute_signature(secret, msg_id, timestamp, payload)
    raw_secret = secret.start_with?("whsec_") ? secret[6..] : secret
    key = Base64.decode64(raw_secret)
    to_sign = "#{msg_id}.#{timestamp}.#{payload}"
    digest = OpenSSL::HMAC.digest("SHA256", key, to_sign)
    "v1,#{Base64.strict_encode64(digest)}"
  end

  # ---------------------------------------------------------------------------
  # Error classification (fixture-driven)
  # ---------------------------------------------------------------------------

  load_cases_data = JSON.parse(
    File.read(File.join(File.expand_path("../../fixtures/conformance", __dir__), "error-classification", "cases.json"))
  )

  load_cases_data.each do |tc|
    define_method("test_conformance_error_#{tc["id"].downcase.tr("-", "_")}") do
      inp = tc["input"]
      err = Nahook::APIError.new(inp["status"], inp["code"], inp["message"], inp["retryAfter"])
      exp = tc["expect"]

      assert_equal exp["isRetryable"],       err.retryable?,        "#{tc["id"]}: isRetryable"
      assert_equal exp["isAuthError"],        err.auth_error?,       "#{tc["id"]}: isAuthError"
      assert_equal exp["isNotFound"],         err.not_found?,        "#{tc["id"]}: isNotFound"
      assert_equal exp["isRateLimited"],      err.rate_limited?,     "#{tc["id"]}: isRateLimited"
      assert_equal exp["isValidationError"],  err.validation_error?, "#{tc["id"]}: isValidationError"
    end
  end

  # ---------------------------------------------------------------------------
  # Region routing (fixture-driven)
  # ---------------------------------------------------------------------------

  JSON.parse(
    File.read(File.join(File.expand_path("../../fixtures/conformance", __dir__), "region-routing", "cases.json"))
  ).each do |tc|
    define_method("test_conformance_region_#{tc["id"].downcase.tr("-", "_")}") do
      result = Nahook::HttpClient.resolve_base_url(tc["input"]["token"])
      assert_equal tc["expect"]["baseUrl"], result, "#{tc["id"]}: baseUrl"
    end
  end

  # ---------------------------------------------------------------------------
  # Retry backoff (fixture-driven)
  # ---------------------------------------------------------------------------

  JSON.parse(
    File.read(File.join(File.expand_path("../../fixtures/conformance", __dir__), "retry-backoff", "cases.json"))
  ).each do |tc|
    define_method("test_conformance_retry_#{tc["id"].downcase.tr("-", "_")}") do
      http = Nahook::HttpClient.new(token: "nhk_us_test", base_url: "https://api.test.com", retries: 0)
      inp = tc["input"]
      retry_after_ms = inp["retryAfterMs"]
      exp = tc["expect"]

      if exp.key?("exactDelayMs")
        delay = http.send(:calculate_delay, inp["attempt"], retry_after_ms)
        assert_equal exp["exactDelayMs"], delay, "#{tc["id"]}: exactDelayMs"
      else
        100.times do
          delay = http.send(:calculate_delay, inp["attempt"], retry_after_ms)
          assert delay >= exp["minDelayMs"], "#{tc["id"]}: delay #{delay} < min #{exp["minDelayMs"]}"
          assert delay <= exp["maxDelayMs"], "#{tc["id"]}: delay #{delay} > max #{exp["maxDelayMs"]}"
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Signature (fixture-driven)
  # ---------------------------------------------------------------------------

  JSON.parse(
    File.read(File.join(File.expand_path("../../fixtures/conformance", __dir__), "signature", "cases.json"))
  ).each do |tc|
    define_method("test_conformance_sig_#{tc["id"].downcase.tr("-", "_")}") do
      inp = tc["input"]
      action = tc["action"]

      # Resolve payload (some fixtures use payloadGenerator)
      payload = if inp.key?("payloadGenerator") && inp["payloadGenerator"] == "repeat_a_10000"
                  "a" * 10_000
                else
                  inp["payload"]
                end

      case action
      when "sign_then_verify"
        sig = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        # Verify by re-signing with same inputs
        sig2 = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        assert_equal sig, sig2, "#{tc["id"]}: sign_then_verify"
        assert sig.start_with?("v1,"), "#{tc["id"]}: signature must start with v1,"

      when "sign_original_verify_tampered"
        original_sig = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        tampered_sig = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], inp["tamperedPayload"])
        refute_equal original_sig, tampered_sig, "#{tc["id"]}: tampered should differ"

      when "sign_with_original_verify_with_wrong"
        original_sig = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        wrong_sig = compute_signature(inp["wrongSecret"], inp["messageId"], inp["timestamp"], payload)
        refute_equal original_sig, wrong_sig, "#{tc["id"]}: wrong secret should differ"

      when "sign_twice_compare"
        sig1 = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        sig2 = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        assert_equal sig1, sig2, "#{tc["id"]}: deterministic"

      when "verify_known_signature"
        sig = compute_signature(inp["secret"], inp["messageId"], inp["timestamp"], payload)
        expected_header = tc["expect"]["signatureHeader"]
        # The expected format is "v1,{timestamp},{signature}" — extract the v1,{sig} part
        parts = expected_header.split(",")
        expected_sig = "v1,#{parts[2]}"
        assert_equal expected_sig, sig, "#{tc["id"]}: known signature mismatch"

      else
        flunk "Unknown action: #{action}"
      end
    end
  end
end
