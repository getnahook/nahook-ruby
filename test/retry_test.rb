# frozen_string_literal: true

require "minitest/autorun"
require "nahook"

class RetryTest < Minitest::Test
  def setup
    @http = Nahook::HttpClient.new(
      token: "nhk_us_test",
      base_url: "https://api.test.com",
      retries: 0
    )
  end

  def test_calculate_delay_between_zero_and_exponential_cap
    100.times do
      delay = @http.send(:calculate_delay, 0)
      assert delay >= 0, "delay should be >= 0, got #{delay}"
      cap = Nahook::HttpClient::BASE_DELAY_MS # 500 * 2^0 = 500
      assert delay <= cap, "delay should be <= #{cap}, got #{delay}"
    end
  end

  def test_calculate_delay_caps_at_max_delay
    100.times do
      delay = @http.send(:calculate_delay, 20) # 2^20 would be huge without cap
      assert delay <= Nahook::HttpClient::MAX_DELAY_MS,
             "delay should be <= #{Nahook::HttpClient::MAX_DELAY_MS}, got #{delay}"
    end
  end

  def test_calculate_delay_uses_retry_after_when_provided
    delay = @http.send(:calculate_delay, 0, 5000)
    assert_equal 5000, delay
  end
end
