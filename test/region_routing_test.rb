# frozen_string_literal: true

require "minitest/autorun"
require "nahook"

class RegionRoutingTest < Minitest::Test
  def test_resolve_base_url_us_region
    assert_equal "https://us.api.nahook.com",
                 Nahook::HttpClient.resolve_base_url("nhk_us_abc123")
  end

  def test_resolve_base_url_eu_region
    assert_equal "https://eu.api.nahook.com",
                 Nahook::HttpClient.resolve_base_url("nhk_eu_abc123")
  end

  def test_resolve_base_url_ap_region
    assert_equal "https://ap.api.nahook.com",
                 Nahook::HttpClient.resolve_base_url("nhk_ap_abc123")
  end

  def test_falls_back_to_default_for_unknown_region
    assert_equal "https://api.nahook.com",
                 Nahook::HttpClient.resolve_base_url("nhk_zz_abc123")
  end

  def test_base_url_parameter_overrides_region
    client = Nahook::Client.new("nhk_us_abc123", base_url: "https://custom.nahook.com")
    http = client.instance_variable_get(:@http)
    conn = http.instance_variable_get(:@conn)
    assert_equal "https://custom.nahook.com", conn.url_prefix.to_s.chomp("/")
  end
end
