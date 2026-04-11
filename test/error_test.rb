# frozen_string_literal: true

require "minitest/autorun"
require "nahook"

class ErrorTest < Minitest::Test
  # -- APIError retryable? --------------------------------------------------

  def test_api_error_retryable_on_500
    error = Nahook::APIError.new(500, "internal_error", "Server error")
    assert error.retryable?
  end

  def test_api_error_retryable_on_429
    error = Nahook::APIError.new(429, "rate_limited", "Too many requests", 5)
    assert error.retryable?
  end

  def test_api_error_not_retryable_on_404
    error = Nahook::APIError.new(404, "not_found", "Not found")
    refute error.retryable?
  end

  # -- APIError auth_error? -------------------------------------------------

  def test_api_error_auth_error_on_401
    error = Nahook::APIError.new(401, "unauthorized", "Invalid token")
    assert error.auth_error?
  end

  # -- APIError not_found? --------------------------------------------------

  def test_api_error_not_found_on_404
    error = Nahook::APIError.new(404, "not_found", "Resource not found")
    assert error.not_found?
  end

  # -- APIError rate_limited? -----------------------------------------------

  def test_api_error_rate_limited_on_429
    error = Nahook::APIError.new(429, "rate_limited", "Too many requests", 10)
    assert error.rate_limited?
    assert_equal 10, error.retry_after
  end

  # -- NetworkError ---------------------------------------------------------

  def test_network_error_wraps_original
    original = StandardError.new("connection refused")
    error = Nahook::NetworkError.new(original)
    assert_equal original, error.original_error
    assert_match(/connection refused/, error.message)
  end

  # -- TimeoutError ---------------------------------------------------------

  def test_timeout_error_stores_timeout
    error = Nahook::TimeoutError.new(15_000)
    assert_equal 15_000, error.timeout_ms
    assert_match(/15000ms/, error.message)
  end
end
