# frozen_string_literal: true

require "minitest/autorun"
require "openssl"
require "base64"

# Webhook signature verification tests.
#
# Validates that the Standard Webhooks signing format used by the Nahook API
# can be correctly produced and verified using native crypto.
#
# Signing spec:
#   base   = "{msgId}.{timestamp}.{payload}"
#   key    = base64_decode(secret_without_whsec_prefix)
#   sig    = "v1," + base64(HMAC-SHA256(key, base))
#   headers: webhook-id, webhook-timestamp, webhook-signature

class WebhookSignatureTest < Minitest::Test
  TEST_SECRET = "whsec_dGVzdF93ZWJob29rX3NpZ25pbmdfa2V5XzMyYnl0ZXMh"
  MSG_ID = "msg_test_sig_001"
  TIMESTAMP = "1712345678"
  PAYLOAD = '{"order_id":"ord_123","amount":49.99}'

  def compute_signature(secret, msg_id, timestamp, payload)
    raw_secret = secret.start_with?("whsec_") ? secret[6..] : secret
    key = Base64.decode64(raw_secret)

    to_sign = "#{msg_id}.#{timestamp}.#{payload}"
    digest = OpenSSL::HMAC.digest("SHA256", key, to_sign)

    "v1,#{Base64.strict_encode64(digest)}"
  end

  def test_produces_valid_v1_signature
    sig = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    assert_match(/\Av1,[A-Za-z0-9+\/]+=*\z/, sig)
  end

  def test_deterministic_same_inputs_same_signature
    sig1 = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    sig2 = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    assert_equal sig1, sig2
  end

  def test_rejects_tampered_payload
    original = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    tampered = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, '{"order_id":"ord_123","amount":99.99}')
    refute_equal original, tampered
  end

  def test_rejects_wrong_secret
    original = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    wrong = compute_signature("whsec_d3Jvbmdfc2VjcmV0", MSG_ID, TIMESTAMP, PAYLOAD)
    refute_equal original, wrong
  end

  def test_rejects_tampered_msg_id
    original = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    tampered = compute_signature(TEST_SECRET, "msg_tampered_id", TIMESTAMP, PAYLOAD)
    refute_equal original, tampered
  end

  def test_rejects_tampered_timestamp
    original = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    tampered = compute_signature(TEST_SECRET, MSG_ID, "9999999999", PAYLOAD)
    refute_equal original, tampered
  end

  def test_correct_headers_structure
    sig = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    headers = {
      "content-type" => "application/json",
      "webhook-id" => MSG_ID,
      "webhook-timestamp" => TIMESTAMP,
      "webhook-signature" => sig
    }

    assert headers["webhook-id"].start_with?("msg_")
    assert headers["webhook-signature"].start_with?("v1,")
    assert_match(/\A\d+\z/, headers["webhook-timestamp"])
    assert_equal "application/json", headers["content-type"]
  end

  def test_handles_secret_without_prefix
    raw_secret = TEST_SECRET[6..]
    with_prefix = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    without_prefix = compute_signature(raw_secret, MSG_ID, TIMESTAMP, PAYLOAD)
    assert_equal with_prefix, without_prefix
  end

  def test_matches_known_cross_language_reference_signature
    sig = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, PAYLOAD)
    assert_equal "v1,VF1JBS4kdSwmE64FeeiWTgszlPCfaop53x8bwzvHizw=", sig
  end

  def test_empty_payload_produces_valid_signature
    sig = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, "")
    assert_equal "v1,yNFeVvBSs4aZ/sVHHw1MaUWnN1IGK/Ul/16T8aptSJo=", sig
  end

  def test_unicode_payload_consistent_across_languages
    sig = compute_signature(TEST_SECRET, MSG_ID, TIMESTAMP, '{"name":"café","price":"€9.99"}')
    assert_equal "v1,GcuGAMV9tELnF2rjay6sA8uo5PDPPlhaFi6gKUg06wQ=", sig
  end
end
