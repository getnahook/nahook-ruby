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
    refute_nil mgmt.environments
    refute_nil mgmt.deliveries
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

  def test_event_types_get
    @stubs.get("/management/v1/workspaces/ws_1/event-types/evt_1") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "evt_1", "name" => "order.paid" })]
    end

    mgmt = build_management
    evt = mgmt.event_types.get("ws_1", "evt_1")
    assert_equal "evt_1", evt["id"]
    assert_equal "order.paid", evt["name"]
    @stubs.verify_stubbed_calls
  end

  def test_event_types_update
    @stubs.patch("/management/v1/workspaces/ws_1/event-types/evt_1") do |env|
      body = JSON.parse(env.body)
      assert_equal "Updated description", body["description"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "evt_1", "description" => "Updated description" })]
    end

    mgmt = build_management
    evt = mgmt.event_types.update("ws_1", "evt_1", description: "Updated description")
    assert_equal "Updated description", evt["description"]
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

  def test_applications_list
    @stubs.get("/management/v1/workspaces/ws_1/applications") do |env|
      assert_nil env.params["limit"]
      assert_nil env.params["offset"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "app_1", "name" => "Acme" }])]
    end

    mgmt = build_management
    result = mgmt.applications.list("ws_1")
    assert_equal 1, result["data"].length
    assert_equal "app_1", result["data"][0]["id"]
    @stubs.verify_stubbed_calls
  end

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

  def test_applications_get
    @stubs.get("/management/v1/workspaces/ws_1/applications/app_1") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "app_1", "name" => "Acme Corp" })]
    end

    mgmt = build_management
    app = mgmt.applications.get("ws_1", "app_1")
    assert_equal "app_1", app["id"]
    assert_equal "Acme Corp", app["name"]
    @stubs.verify_stubbed_calls
  end

  def test_applications_update
    @stubs.patch("/management/v1/workspaces/ws_1/applications/app_1") do |env|
      body = JSON.parse(env.body)
      assert_equal "Acme Inc", body["name"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "app_1", "name" => "Acme Inc" })]
    end

    mgmt = build_management
    app = mgmt.applications.update("ws_1", "app_1", name: "Acme Inc")
    assert_equal "Acme Inc", app["name"]
    @stubs.verify_stubbed_calls
  end

  def test_applications_delete
    @stubs.delete("/management/v1/workspaces/ws_1/applications/app_1") do
      [204, {}, ""]
    end

    mgmt = build_management
    result = mgmt.applications.delete("ws_1", "app_1")
    assert_nil result
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

  # -- Environments ---------------------------------------------------

  def test_environments_list
    @stubs.get("/management/v1/workspaces/ws_1/environments") do |env|
      assert_equal "Bearer #{@token}", env.request_headers["Authorization"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "id" => "env_1", "name" => "Production", "slug" => "production", "isDefault" => true }])]
    end

    mgmt = build_management
    result = mgmt.environments.list("ws_1")
    assert_equal 1, result["data"].length
    assert_equal "env_1", result["data"][0]["id"]
    @stubs.verify_stubbed_calls
  end

  def test_environments_create
    @stubs.post("/management/v1/workspaces/ws_1/environments") do |env|
      body = JSON.parse(env.body)
      assert_equal "Staging", body["name"]
      assert_equal "staging", body["slug"]
      assert_equal "application/json", env.request_headers["Content-Type"]
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "env_new", "name" => "Staging", "slug" => "staging", "isDefault" => false })]
    end

    mgmt = build_management
    env = mgmt.environments.create("ws_1", name: "Staging", slug: "staging")
    assert_equal "env_new", env["id"]
    @stubs.verify_stubbed_calls
  end

  def test_environments_get
    @stubs.get("/management/v1/workspaces/ws_1/environments/env_1") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "env_1", "name" => "Production" })]
    end

    mgmt = build_management
    env = mgmt.environments.get("ws_1", "env_1")
    assert_equal "env_1", env["id"]
    @stubs.verify_stubbed_calls
  end

  def test_environments_update
    @stubs.patch("/management/v1/workspaces/ws_1/environments/env_1") do |env|
      body = JSON.parse(env.body)
      assert_equal "Pre-production", body["name"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "env_1", "name" => "Pre-production" })]
    end

    mgmt = build_management
    env = mgmt.environments.update("ws_1", "env_1", name: "Pre-production")
    assert_equal "Pre-production", env["name"]
    @stubs.verify_stubbed_calls
  end

  def test_environments_delete
    @stubs.delete("/management/v1/workspaces/ws_1/environments/env_1") do
      [204, {}, ""]
    end

    mgmt = build_management
    result = mgmt.environments.delete("ws_1", "env_1")
    assert_nil result
    @stubs.verify_stubbed_calls
  end

  def test_environments_list_event_type_visibility
    @stubs.get("/management/v1/workspaces/ws_1/environments/env_1/event-types") do
      [200, { "Content-Type" => "application/json" }, JSON.generate([{ "eventTypeName" => "order.created", "published" => true }])]
    end

    mgmt = build_management
    result = mgmt.environments.list_event_type_visibility("ws_1", "env_1")
    assert_equal 1, result["data"].length
    assert_equal true, result["data"][0]["published"]
    @stubs.verify_stubbed_calls
  end

  def test_environments_set_event_type_visibility
    @stubs.put("/management/v1/workspaces/ws_1/environments/env_1/event-types/evt_1/visibility") do |env|
      body = JSON.parse(env.body)
      assert_equal true, body["published"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "eventTypeName" => "order.created", "published" => true })]
    end

    mgmt = build_management
    vis = mgmt.environments.set_event_type_visibility("ws_1", "env_1", "evt_1", published: true)
    assert_equal true, vis["published"]
    @stubs.verify_stubbed_calls
  end

  # -- Deliveries ----------------------------------------------------

  def test_list_returns_paginated_data_and_next_cursor
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_1/deliveries") do |env|
      assert_equal "Bearer #{@token}", env.request_headers["Authorization"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({
        "deliveries" => [
          { "id" => "del_a", "endpointId" => "ep_1", "status" => "delivered", "hasPayload" => true,
            "totalAttempts" => 1, "firstAttemptAt" => "2026-05-28T14:30:59Z",
            "deliveredAt" => "2026-05-28T14:30:59Z", "nextRetryAt" => nil,
            "idempotencyKey" => "k1", "createdAt" => "2026-05-28T14:30:59Z", "updatedAt" => "2026-05-28T14:30:59Z" },
          { "id" => "del_b", "endpointId" => "ep_1", "status" => "failed", "hasPayload" => false,
            "totalAttempts" => 3, "firstAttemptAt" => "2026-05-28T14:31:00Z",
            "deliveredAt" => nil, "nextRetryAt" => nil,
            "idempotencyKey" => "k2", "createdAt" => "2026-05-28T14:31:00Z", "updatedAt" => "2026-05-28T14:31:00Z" }
        ],
        "nextCursor" => "opaque-token-aaa"
      })]
    end

    mgmt = build_management
    result = mgmt.deliveries.list("ws_1", "ep_1")
    assert_kind_of Nahook::PaginatedResult, result
    assert_equal 2, result.data.length
    assert_equal "del_a", result.data[0]["id"]
    assert_equal "opaque-token-aaa", result.next_cursor
    @stubs.verify_stubbed_calls
  end

  def test_list_returns_null_cursor_when_last_page
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_1/deliveries") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({
        "deliveries" => [],
        "nextCursor" => nil
      })]
    end

    mgmt = build_management
    result = mgmt.deliveries.list("ws_1", "ep_1")
    assert_equal [], result.data
    assert_nil result.next_cursor
    @stubs.verify_stubbed_calls
  end

  def test_list_forwards_query_params
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_1/deliveries") do |env|
      assert_equal "25", env.params["limit"]
      assert_equal "opaque-token-xyz", env.params["cursor"]
      assert_equal "failed", env.params["status"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "deliveries" => [], "nextCursor" => nil })]
    end

    mgmt = build_management
    mgmt.deliveries.list("ws_1", "ep_1", limit: 25, cursor: "opaque-token-xyz", status: "failed")
    @stubs.verify_stubbed_calls
  end

  def test_list_omits_unset_query_params
    @stubs.get("/management/v1/workspaces/ws_1/endpoints/ep_1/deliveries") do |env|
      assert_nil env.params["limit"]
      assert_nil env.params["cursor"]
      assert_nil env.params["status"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({ "deliveries" => [], "nextCursor" => nil })]
    end

    mgmt = build_management
    mgmt.deliveries.list("ws_1", "ep_1")
    @stubs.verify_stubbed_calls
  end

  def test_get_returns_metadata_without_envelope_by_default
    @stubs.get("/management/v1/workspaces/ws_1/deliveries/del_a") do |env|
      assert_nil env.params["include"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({
        "id" => "del_a", "idempotencyKey" => "k1", "endpointId" => "ep_1",
        "status" => "delivered", "totalAttempts" => 1,
        "firstAttemptAt" => "2026-05-28T14:30:59Z", "deliveredAt" => "2026-05-28T14:30:59Z",
        "nextRetryAt" => nil, "hasPayload" => true,
        "createdAt" => "2026-05-28T14:30:59Z", "updatedAt" => "2026-05-28T14:30:59Z"
      })]
    end

    mgmt = build_management
    delivery = mgmt.deliveries.get("ws_1", "del_a")
    assert_equal "del_a", delivery["id"]
    assert_equal true, delivery["hasPayload"]
    refute delivery.key?("payload"), "metadata-only response must not include 'payload'"
    @stubs.verify_stubbed_calls
  end

  def test_get_with_include_payload_returns_envelope
    @stubs.get("/management/v1/workspaces/ws_1/deliveries/del_a") do |env|
      assert_equal "payload", env.params["include"]
      [200, { "Content-Type" => "application/json" }, JSON.generate({
        "id" => "del_a", "idempotencyKey" => "k1", "endpointId" => "ep_1",
        "status" => "delivered", "totalAttempts" => 1,
        "firstAttemptAt" => "2026-05-28T14:30:59Z", "deliveredAt" => "2026-05-28T14:30:59Z",
        "nextRetryAt" => nil, "hasPayload" => true,
        "createdAt" => "2026-05-28T14:30:59Z", "updatedAt" => "2026-05-28T14:30:59Z",
        "payload" => { "status" => "available", "data" => { "orderId" => "ord_123" }, "contentType" => "application/json" }
      })]
    end

    mgmt = build_management
    delivery = mgmt.deliveries.get("ws_1", "del_a", include_payload: true)
    assert_equal "available", delivery["payload"]["status"]
    assert_equal "ord_123", delivery["payload"]["data"]["orderId"]
    assert_equal "application/json", delivery["payload"]["contentType"]
    @stubs.verify_stubbed_calls
  end

  def test_get_returns_forbidden_envelope_for_plan_gated_workspace
    @stubs.get("/management/v1/workspaces/ws_1/deliveries/del_a") do
      [200, { "Content-Type" => "application/json" }, JSON.generate({
        "id" => "del_a", "idempotencyKey" => "k1", "endpointId" => "ep_1",
        "status" => "delivered", "totalAttempts" => 1,
        "firstAttemptAt" => nil, "deliveredAt" => "2026-05-28T14:30:59Z",
        "nextRetryAt" => nil, "hasPayload" => true,
        "createdAt" => "2026-05-28T14:30:59Z", "updatedAt" => "2026-05-28T14:30:59Z",
        "payload" => { "status" => "forbidden" }
      })]
    end

    mgmt = build_management
    delivery = mgmt.deliveries.get("ws_1", "del_a", include_payload: true)
    assert_equal({ "status" => "forbidden" }, delivery["payload"])
    @stubs.verify_stubbed_calls
  end

  def test_get_attempts_returns_array
    @stubs.get("/management/v1/workspaces/ws_1/deliveries/del_a/attempts") do
      [200, { "Content-Type" => "application/json" }, JSON.generate([
        { "id" => "att_1", "attemptNumber" => 1, "status" => "failed",
          "responseStatusCode" => 502, "responseTimeMs" => 142,
          "errorMessage" => "Bad gateway", "createdAt" => "2026-05-28T14:31:00Z" },
        { "id" => "att_2", "attemptNumber" => 2, "status" => "success",
          "responseStatusCode" => 200, "responseTimeMs" => 88,
          "errorMessage" => nil, "createdAt" => "2026-05-28T14:31:30Z" }
      ])]
    end

    mgmt = build_management
    attempts = mgmt.deliveries.get_attempts("ws_1", "del_a")
    assert_kind_of Array, attempts
    assert_equal 2, attempts.length
    assert_equal 1, attempts[0]["attemptNumber"]
    assert_equal "success", attempts[1]["status"]
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

  # -- Headers (dedicated) ------------------------------------------------

  def test_header_authorization_bearer
    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do |env|
      assert_equal "Bearer #{@token}", env.request_headers["Authorization"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([])]
    end

    mgmt = build_management
    mgmt.endpoints.list("ws_1")
    @stubs.verify_stubbed_calls
  end

  def test_header_user_agent_prefix
    @stubs.get("/management/v1/workspaces/ws_1/endpoints") do |env|
      assert_match %r{\Anahook-ruby/}, env.request_headers["User-Agent"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([])]
    end

    mgmt = build_management
    mgmt.endpoints.list("ws_1")
    @stubs.verify_stubbed_calls
  end

  def test_header_content_type_on_post
    @stubs.post("/management/v1/workspaces/ws_1/endpoints") do |env|
      assert_equal "application/json", env.request_headers["Content-Type"]
      [201, { "Content-Type" => "application/json" }, JSON.generate({ "id" => "ep_1" })]
    end

    mgmt = build_management
    mgmt.endpoints.create("ws_1", url: "https://example.com/hook")
    @stubs.verify_stubbed_calls
  end

  def test_header_no_content_type_on_get
    @stubs.get("/management/v1/workspaces/ws_1/environments") do |env|
      assert_nil env.request_headers["Content-Type"]
      [200, { "Content-Type" => "application/json" }, JSON.generate([])]
    end

    mgmt = build_management
    mgmt.environments.list("ws_1")
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
     mgmt.subscriptions, mgmt.portal_sessions, mgmt.environments,
     mgmt.deliveries].each do |resource|
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
