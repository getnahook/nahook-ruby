# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "nahook"

class ManagementTest < Minitest::Test
  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    @token = "nhm_test_token"
  end

  def build_management(token: @token)
    mgmt = Nahook::Management.new(token, base_url: "https://api.test.com")
    # Replace the adapter in each resource's http client
    replace_adapter(mgmt)
    mgmt
  end

  # -- Token validation ---------------------------------------------------

  def test_rejects_invalid_token_prefix
    assert_raises(ArgumentError) { Nahook::Management.new("bad_token") }
  end

  def test_accepts_valid_management_token
    mgmt = Nahook::Management.new("nhm_test123")
    refute_nil mgmt.endpoints
    refute_nil mgmt.event_types
    refute_nil mgmt.applications
    refute_nil mgmt.subscriptions
    refute_nil mgmt.portal_sessions
  end

  # -- Endpoints ----------------------------------------------------------

  def test_endpoints_list
    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do |env|
      assert_equal "Bearer #{@token}", env.request_headers["Authorization"]
      assert_match %r{nahook-ruby/}, env.request_headers["User-Agent"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "ep_1", "url" => "https://example.com" }])]
    end

    mgmt = build_management
    result = mgmt.endpoints.list("ws_1")
    assert_equal 1, result["data"].length
    assert_equal "ep_1", result["data"][0]["id"]
    @stubs.verify_stubbed_calls
  end

  def test_endpoints_create
    @stubs.post("/management/v1/workspaces/ws_1/endpoints") do |env|
      body = JSON.parse(env.body)
      assert_equal "https://example.com/hook", body["url"]
      assert_equal "webhook", body["type"]
      assert_equal "application/json", env.request_headers["Content-Type"]
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "ep_new", "url" => body["url"] })]
    end

    mgmt = build_management
    ep = mgmt.endpoints.create("ws_1", url: "https://example.com/hook", type: "webhook")
    assert_equal "ep_new", ep["id"]
    @stubs.verify_stubbed_calls
  end

  def test_endpoints_get
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_1") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "ep_1" })]
    end

    mgmt = build_management
    ep = mgmt.endpoints.get("ws_1", "ep_1")
    assert_equal "ep_1", ep["id"]
    @stubs.verify_stubbed_calls
  end

  def test_endpoints_update
    @stubs.patch("/management/v1/workspaces/ws_1/endpoints/ep_1") do |env|
      body = JSON.parse(env.body)
      assert_equal false, body["isActive"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "ep_1", "isActive" => false })]
    end

    mgmt = build_management
    ep = mgmt.endpoints.update("ws_1", "ep_1", is_active: false)
    assert_equal false, ep["isActive"]
    @stubs.verify_stubbed_calls
  end

  def test_endpoints_delete
    @stubs.delete("/management/v1/workspaces/ws_1/endpoints/ep_1") do
      [204, {}, ""]
    end

    mgmt = build_management
    result = mgmt.endpoints.delete("ws_1", "ep_1")
    assert_nil result
    @stubs.verify_stubbed_calls
  end

  # -- Event Types --------------------------------------------------------

  def test_event_types_list
    @stubs.get("/management/v1/workspaces/ws_1/event-types") do
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "evt_1", "name" => "order.paid" }])]
    end

    mgmt = build_management
    result = mgmt.event_types.list("ws_1")
    assert_equal "order.paid", result["data"][0]["name"]
    @stubs.verify_stubbed_calls
  end

  def test_event_types_create
    @stubs.post("/management/v1/workspaces/ws_1/event-types") do |env|
      body = JSON.parse(env.body)
      assert_equal "user.created", body["name"]
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "evt_new", "name" => "user.created" })]
    end

    mgmt = build_management
    evt = mgmt.event_types.create("ws_1", name: "user.created")
    assert_equal "evt_new", evt["id"]
    @stubs.verify_stubbed_calls
  end

  def test_event_types_delete
    @stubs.delete("/management/v1/workspaces/ws_1/event-types/evt_1") do
      [204, {}, ""]
    end

    mgmt = build_management
    result = mgmt.event_types.delete("ws_1", "evt_1")
    assert_nil result
    @stubs.verify_stubbed_calls
  end

  # -- Applications -------------------------------------------------------

  def test_applications_list_with_pagination
    @stubs.get("/management/v1/workspaces/ws_1/applications") do |env|
      assert_equal "10", env.params["limit"]
      assert_equal "5", env.params["offset"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "app_1" }])]
    end

    mgmt = build_management
    result = mgmt.applications.list("ws_1", limit: 10, offset: 5)
    assert_equal 1, result["data"].length
    @stubs.verify_stubbed_calls
  end

  def test_applications_create
    @stubs.post("/management/v1/workspaces/ws_1/applications") do |env|
      body = JSON.parse(env.body)
      assert_equal "Acme Corp", body["name"]
      assert_equal "ext_123", body["externalId"]
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "app_new", "name" => "Acme Corp" })]
    end

    mgmt = build_management
    app = mgmt.applications.create("ws_1", name: "Acme Corp", external_id: "ext_123")
    assert_equal "app_new", app["id"]
    @stubs.verify_stubbed_calls
  end

  def test_applications_list_endpoints
    @stubs.get("/management/v1/workspaces/ws_1/applications/app_1/endpoints") do
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "ep_1" }])]
    end

    mgmt = build_management
    result = mgmt.applications.list_endpoints("ws_1", "app_1")
    assert_equal 1, result["data"].length
    @stubs.verify_stubbed_calls
  end

  def test_applications_create_endpoint
    @stubs.post("/management/v1/workspaces/ws_1/applications/app_1/endpoints") do |env|
      body = JSON.parse(env.body)
      assert_equal "https://example.com/hook", body["url"]
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "ep_new" })]
    end

    mgmt = build_management
    ep = mgmt.applications.create_endpoint("ws_1", "app_1", url: "https://example.com/hook")
    assert_equal "ep_new", ep["id"]
    @stubs.verify_stubbed_calls
  end

  # -- Subscriptions ------------------------------------------------------

  def test_subscriptions_list
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_1/subscriptions") do
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "sub_1" }])]
    end

    mgmt = build_management
    result = mgmt.subscriptions.list("ws_1", "ep_1")
    assert_equal 1, result["data"].length
    @stubs.verify_stubbed_calls
  end

  def test_subscriptions_create
    @stubs.post("/management/v1/workspaces/ws_1/endpoints/ep_1/subscriptions") do |env|
      body = JSON.parse(env.body)
      assert_equal ["evt_1"], body["eventTypeIds"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "subscribed" => 1 })]
    end

    mgmt = build_management
    sub = mgmt.subscriptions.create("ws_1", "ep_1", event_type_ids: ["evt_1"])
    assert_equal 1, sub["subscribed"]
    @stubs.verify_stubbed_calls
  end

  def test_subscriptions_delete
    @stubs.delete("/management/v1/workspaces/ws_1/endpoints/ep_1/subscriptions/evt_1") do
      [204, {}, ""]
    end

    mgmt = build_management
    result = mgmt.subscriptions.delete("ws_1", "ep_1", "evt_1")
    assert_nil result
    @stubs.verify_stubbed_calls
  end

  # -- Portal Sessions ----------------------------------------------------

  def test_portal_sessions_create
    @stubs.post("/management/v1/workspaces/ws_1/applications/app_1/portal") do |env|
      body = JSON.parse(env.body)
      assert_equal({}, body) # empty body when no metadata
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "url" => "https://portal.nahook.com/s/abc", "code" => "abc", "expiresAt" => "2026-01-01T00:00:00Z" })]
    end

    mgmt = build_management
    session = mgmt.portal_sessions.create("ws_1", "app_1")
    assert_equal "https://portal.nahook.com/s/abc", session["url"]
    assert_equal "abc", session["code"]
    @stubs.verify_stubbed_calls
  end

  def test_portal_sessions_create_with_metadata
    @stubs.post("/management/v1/workspaces/ws_1/applications/app_1/portal") do |env|
      body = JSON.parse(env.body)
      assert_equal({ "tier" => "pro" }, body["metadata"])
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "url" => "https://portal.nahook.com/s/xyz" })]
    end

    mgmt = build_management
    session = mgmt.portal_sessions.create("ws_1", "app_1", metadata: { "tier" => "pro" })
    refute_nil session["url"]
    @stubs.verify_stubbed_calls
  end

  # -- Error handling -----------------------------------------------------

  def test_api_error_on_404
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_missing") do
      [404, { "Content-Type" => "application/json" }, JSON.generate({ "error" => { "code" => "not_found", "message" => "Endpoint not found" } })]
    end

    mgmt = build_management
    error = assert_raises(Nahook::APIError) { mgmt.endpoints.get("ws_1", "ep_missing") }
    assert_equal 404, error.status
    assert_equal "not_found", error.code
    assert error.not_found?
    refute error.retryable?
    @stubs.verify_stubbed_calls
  end

  def test_api_error_on_401
    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do
      [401, { "Content-Type" => "application/json" }, JSON.generate({ "error" => { "code" => "unauthorized", "message" => "Invalid token" } })]
    end

    mgmt = build_management
    error = assert_raises(Nahook::APIError) { mgmt.endpoints.list("ws_1") }
    assert error.auth_error?
    @stubs.verify_stubbed_calls
  end

  def test_no_content_type_on_get_requests
    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do |env|
      assert_nil env.request_headers["Content-Type"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([])]
    end

    mgmt = build_management
    mgmt.endpoints.list("ws_1")
    @stubs.verify_stubbed_calls
  end

  # -- URL encoding -------------------------------------------------------

  def test_url_encodes_path_segments
    @stubs.get("/management/v1/workspaces/ws%2F1/endpoints/ep%2F1") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "ep/1" })]
    end

    mgmt = build_management
    ep = mgmt.endpoints.get("ws/1", "ep/1")
    assert_equal "ep/1", ep["id"]
    @stubs.verify_stubbed_calls
  end

  private

  def replace_adapter(mgmt)
    # Access http client through resources and swap the Faraday connection
    [mgmt.endpoints, mgmt.event_types, mgmt.applications,
     mgmt.subscriptions, mgmt.portal_sessions].each do |resource|
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
