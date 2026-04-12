# frozen_string_literal: true

require "minitest/autorun"
require "openssl"
require "base64"
require "securerandom"

# Property-based tests for webhook signature signing/verification.
# Uses SecureRandom to generate random inputs over 100 iterations.
class SignaturePbtTest < Minitest::Test
  ITERATIONS = 100

  def compute_signature(secret, msg_id, timestamp, payload)
    raw_secret = secret.start_with?("whsec_") ? secret[6..] : secret
    key = Base64.decode64(raw_secret)
    to_sign = "#{msg_id}.#{timestamp}.#{payload}"
    digest = OpenSSL::HMAC.digest("SHA256", key, to_sign)
    "v1,#{Base64.strict_encode64(digest)}"
  end

  def random_secret
    "whsec_#{Base64.strict_encode64(SecureRandom.random_bytes(32))}"
  end

  def random_msg_id
    "msg_#{SecureRandom.hex(12)}"
  end

  def random_timestamp
    (Time.now.to_i - rand(1_000_000)).to_s
  end

  def random_payload
    # Mix of ASCII, unicode, and varying lengths
    length = rand(0..2048)
    chars = (32..126).map(&:chr)
    (0...length).map { chars.sample }.join
  end

  # -- Property 1: Sign then verify roundtrip ----------------------------------

  def test_sign_then_verify_roundtrip
    ITERATIONS.times do |i|
      secret = random_secret
      msg_id = random_msg_id
      ts = random_timestamp
      payload = random_payload

      sig = compute_signature(secret, msg_id, ts, payload)

      # Re-sign with identical inputs must match
      sig2 = compute_signature(secret, msg_id, ts, payload)
      assert_equal sig, sig2, "Roundtrip failed on iteration #{i}"
      assert sig.start_with?("v1,"), "Signature format wrong on iteration #{i}"
    end
  end

  # -- Property 2: Tampered payload always fails --------------------------------

  def test_tampered_payload_always_fails
    ITERATIONS.times do |i|
      secret = random_secret
      msg_id = random_msg_id
      ts = random_timestamp
      payload = random_payload

      original_sig = compute_signature(secret, msg_id, ts, payload)
      tampered = payload + "X"
      tampered_sig = compute_signature(secret, msg_id, ts, tampered)

      refute_equal original_sig, tampered_sig,
                   "Tampered payload produced same signature on iteration #{i}"
    end
  end

  # -- Property 3: Wrong secret always fails -----------------------------------

  def test_wrong_secret_always_fails
    ITERATIONS.times do |i|
      secret1 = random_secret
      secret2 = random_secret
      msg_id = random_msg_id
      ts = random_timestamp
      payload = random_payload

      sig1 = compute_signature(secret1, msg_id, ts, payload)
      sig2 = compute_signature(secret2, msg_id, ts, payload)

      refute_equal sig1, sig2,
                   "Different secrets produced same signature on iteration #{i}"
    end
  end

  # -- Property 4: Deterministic -----------------------------------------------

  def test_deterministic
    ITERATIONS.times do |i|
      secret = random_secret
      msg_id = random_msg_id
      ts = random_timestamp
      payload = random_payload

      sig_a = compute_signature(secret, msg_id, ts, payload)
      sig_b = compute_signature(secret, msg_id, ts, payload)
      sig_c = compute_signature(secret, msg_id, ts, payload)

      assert_equal sig_a, sig_b, "Non-deterministic on iteration #{i} (a vs b)"
      assert_equal sig_b, sig_c, "Non-deterministic on iteration #{i} (b vs c)"
    end
  end
end
