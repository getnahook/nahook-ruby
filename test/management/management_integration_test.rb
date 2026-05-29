# frozen_string_literal: true

require "minitest/autorun"
require "nahook"

class ManagementIntegrationTest < Minitest::Test
  def setup
    @api_url      = ENV["NAHOOK_TEST_API_URL"]
    @mgmt_token   = ENV["NAHOOK_TEST_MGMT_TOKEN"]
    @workspace_id = ENV["NAHOOK_TEST_WORKSPACE_ID"]

    unless @api_url && @mgmt_token && @workspace_id
      skip "management integration env not set"
    end

    @mgmt = Nahook::Management.new(@mgmt_token, base_url: @api_url)
    @suffix = Time.now.to_i
  end

  # -- event types CRUD ----------------------------------------------------

  def test_event_types_crud
    # Create
    created = @mgmt.event_types.create(@workspace_id,
      name: "mgmt.test.ruby.#{@suffix}",
      description: "Ruby integration test event type"
    )
    assert created["id"], "created event type should have an id"
    et_id = created["id"]

    # List
    list_result = @mgmt.event_types.list(@workspace_id)
    assert_kind_of Array, list_result["data"]
    ids = list_result["data"].map { |et| et["id"] }
    assert_includes ids, et_id

    # Get
    fetched = @mgmt.event_types.get(@workspace_id, et_id)
    assert_equal et_id, fetched["id"]
    assert_equal "mgmt.test.ruby.#{@suffix}", fetched["name"]

    # Update
    updated = @mgmt.event_types.update(@workspace_id, et_id,
      description: "Updated description"
    )
    assert_equal "Updated description", updated["description"]

    # Delete
    @mgmt.event_types.delete(@workspace_id, et_id)

    # Verify deletion — get should 404
    err = assert_raises(Nahook::APIError) do
      @mgmt.event_types.get(@workspace_id, et_id)
    end
    assert_equal 404, err.status
  end

  # -- endpoints CRUD ------------------------------------------------------

  def test_endpoints_crud
    # Create
    created = @mgmt.endpoints.create(@workspace_id,
      url: "https://example.com/ruby-mgmt-test-#{@suffix}",
      description: "Ruby management integration test"
    )
    assert created["id"], "created endpoint should have an id"
    assert_match(/^ep_/, created["id"])
    ep_id = created["id"]

    # List
    list_result = @mgmt.endpoints.list(@workspace_id)
    assert_kind_of Array, list_result["data"]
    ids = list_result["data"].map { |ep| ep["id"] }
    assert_includes ids, ep_id

    # Get
    fetched = @mgmt.endpoints.get(@workspace_id, ep_id)
    assert_equal ep_id, fetched["id"]
    assert_match(/ruby-mgmt-test-#{@suffix}/, fetched["url"])

    # Update
    updated = @mgmt.endpoints.update(@workspace_id, ep_id,
      description: "Updated endpoint description"
    )
    assert_equal "Updated endpoint description", updated["description"]

    # Delete
    @mgmt.endpoints.delete(@workspace_id, ep_id)

    err = assert_raises(Nahook::APIError) do
      @mgmt.endpoints.get(@workspace_id, ep_id)
    end
    assert_equal 404, err.status
  end

  # -- applications CRUD ---------------------------------------------------

  def test_applications_crud
    # Create
    created = @mgmt.applications.create(@workspace_id,
      name: "Ruby Test App #{@suffix}",
      metadata: { "env" => "test" }
    )
    assert created["id"], "created application should have an id"
    app_id = created["id"]

    # List
    list_result = @mgmt.applications.list(@workspace_id)
    assert_kind_of Array, list_result["data"]
    ids = list_result["data"].map { |app| app["id"] }
    assert_includes ids, app_id

    # Get
    fetched = @mgmt.applications.get(@workspace_id, app_id)
    assert_equal app_id, fetched["id"]
    assert_equal "Ruby Test App #{@suffix}", fetched["name"]

    # Update
    updated = @mgmt.applications.update(@workspace_id, app_id,
      name: "Ruby Test App #{@suffix} Updated"
    )
    assert_equal "Ruby Test App #{@suffix} Updated", updated["name"]

    # Delete
    @mgmt.applications.delete(@workspace_id, app_id)

    err = assert_raises(Nahook::APIError) do
      @mgmt.applications.get(@workspace_id, app_id)
    end
    assert_equal 404, err.status
  end

  # -- subscriptions lifecycle ---------------------------------------------

  def test_subscriptions_lifecycle
    # Set up: create an endpoint and an event type
    ep = @mgmt.endpoints.create(@workspace_id,
      url: "https://example.com/ruby-sub-test-#{@suffix}",
      description: "Subscription lifecycle test"
    )
    ep_id = ep["id"]

    et = @mgmt.event_types.create(@workspace_id,
      name: "sub.lifecycle.ruby.#{@suffix}",
      description: "Subscription lifecycle event type"
    )
    et_id = et["id"]

    begin
      # Subscribe (plural array, returns { "subscribed" => N })
      sub = @mgmt.subscriptions.create(@workspace_id, ep_id, event_type_ids: [et_id])
      assert_equal 1, sub["subscribed"], "should report 1 subscribed event type"

      # List subscriptions
      list_result = @mgmt.subscriptions.list(@workspace_id, ep_id)
      assert_kind_of Array, list_result["data"]
      refute_empty list_result["data"], "endpoint should have at least one subscription"
      listed_et_ids = list_result["data"].map { |s| s["eventTypeId"] }
      assert_includes listed_et_ids, et_id

      # Unsubscribe (event type public_id in path, returns 204)
      @mgmt.subscriptions.delete(@workspace_id, ep_id, et_id)

      # Verify unsubscribed
      after_delete = @mgmt.subscriptions.list(@workspace_id, ep_id)
      remaining_et_ids = (after_delete["data"] || []).map { |s| s["eventTypeId"] }
      refute_includes remaining_et_ids, et_id
    ensure
      # Cleanup
      @mgmt.endpoints.delete(@workspace_id, ep_id) rescue nil
      @mgmt.event_types.delete(@workspace_id, et_id) rescue nil
    end
  end

  # -- environments CRUD ---------------------------------------------------

  def test_environments_crud
    # Create
    created = @mgmt.environments.create(@workspace_id,
      name: "Ruby Test Env #{@suffix}",
      slug: "ruby-test-env-#{@suffix}"
    )
    assert created["id"], "created environment should have an id"
    env_id = created["id"]
    assert_equal "Ruby Test Env #{@suffix}", created["name"]
    assert_equal "ruby-test-env-#{@suffix}", created["slug"]

    # Create a second environment to verify list returns >= 2
    created2 = @mgmt.environments.create(@workspace_id,
      name: "Ruby Test Env2 #{@suffix}",
      slug: "ruby-test-env2-#{@suffix}"
    )
    env_id2 = created2["id"]

    begin
      # List
      list_result = @mgmt.environments.list(@workspace_id)
      assert_kind_of Array, list_result["data"]
      assert list_result["data"].size >= 2, "should have at least 2 environments"
      ids = list_result["data"].map { |env| env["id"] }
      assert_includes ids, env_id
      assert_includes ids, env_id2

      # Get
      fetched = @mgmt.environments.get(@workspace_id, env_id)
      assert_equal env_id, fetched["id"]
      assert_equal "Ruby Test Env #{@suffix}", fetched["name"]

      # Update
      updated = @mgmt.environments.update(@workspace_id, env_id,
        name: "Ruby Test Env #{@suffix} Updated"
      )
      assert_equal "Ruby Test Env #{@suffix} Updated", updated["name"]

      # Delete
      @mgmt.environments.delete(@workspace_id, env_id)

      # Verify deletion — get should 404
      err = assert_raises(Nahook::APIError) do
        @mgmt.environments.get(@workspace_id, env_id)
      end
      assert_equal 404, err.status
    ensure
      @mgmt.environments.delete(@workspace_id, env_id2) rescue nil
    end
  end

  # -- environment event type visibility -----------------------------------

  def test_event_type_visibility
    # Set up: create an environment and an event type
    env = @mgmt.environments.create(@workspace_id,
      name: "Visibility Test #{@suffix}",
      slug: "visibility-test-#{@suffix}"
    )
    env_id = env["id"]

    et = @mgmt.event_types.create(@workspace_id,
      name: "env.visibility.ruby.#{@suffix}",
      description: "Environment visibility test event type"
    )
    et_id = et["id"]

    begin
      # List visibility
      list_result = @mgmt.environments.list_event_type_visibility(@workspace_id, env_id)
      assert_kind_of Array, list_result["data"]

      # Set published = true
      visibility = @mgmt.environments.set_event_type_visibility(
        @workspace_id, env_id, et_id, published: true
      )
      assert_equal et_id, visibility["eventTypeId"]
      assert_equal true, visibility["published"]

      # Verify in list
      after = @mgmt.environments.list_event_type_visibility(@workspace_id, env_id)
      entry = after["data"].find { |v| v["eventTypeId"] == et_id }
      assert entry, "event type should appear in visibility list"
      assert_equal true, entry["published"]
    ensure
      @mgmt.environments.delete(@workspace_id, env_id) rescue nil
      @mgmt.event_types.delete(@workspace_id, et_id) rescue nil
    end
  end

  # -- deliveries (reads against pre-seeded fixture rows) ------------------
  #
  # Fixture data lives in packages/db/src/seeds/test-fixtures.sql:
  #   del_fixture_001 -- delivered, hasPayload=true
  #   del_fixture_002 -- failed, 3 attempts, hasPayload=false
  #   del_fixture_003 -- delivering, hasPayload=false
  # All three scoped to ep_integration_test_001.

  def test_deliveries_list_paginates_with_opaque_cursor
    result = @mgmt.deliveries.list(@workspace_id, "ep_integration_test_001", limit: 2)
    assert_kind_of Nahook::PaginatedResult, result
    assert_equal 2, result.data.length
    ids = result.data.map { |d| d["id"] }
    assert_includes ids, "del_fixture_003" # newest-first, in flight delivery
    # With 3 fixture rows and limit=2 we expect a non-null nextCursor.
    assert_kind_of String, result.next_cursor
    refute_match(/^del_/, result.next_cursor) # opaque, not a leaked publicId
  end

  def test_deliveries_list_with_status_filter_returns_failed_fixture
    result = @mgmt.deliveries.list(@workspace_id, "ep_integration_test_001", status: "failed")
    assert_equal 1, result.data.length
    failed = result.data[0]
    assert_equal "del_fixture_002", failed["id"]
    assert_equal "failed", failed["status"]
    assert_equal 3, failed["totalAttempts"]
    assert_equal false, failed["hasPayload"]
  end

  def test_deliveries_get_returns_metadata_without_payload_by_default
    delivery = @mgmt.deliveries.get(@workspace_id, "del_fixture_001")
    assert_equal "del_fixture_001", delivery["id"]
    assert_equal "ep_integration_test_001", delivery["endpointId"]
    assert_equal "delivered", delivery["status"]
    assert_equal true, delivery["hasPayload"]
    refute delivery.key?("payload"), "default get() must not include 'payload' envelope"
  end

  def test_deliveries_get_with_include_payload_returns_envelope
    delivery = @mgmt.deliveries.get(@workspace_id, "del_fixture_001", include_payload: true)
    refute_nil delivery["payload"], "payload envelope should be present"
    # R2 wiring may be absent in the test infra, in which case the envelope
    # reports "error" or "not_found". All 5 status values are valid wire-level
    # responses -- do not strict-assert "available".
    assert_includes %w[available forbidden processing not_found error],
                    delivery["payload"]["status"]
  end

  def test_deliveries_get_attempts_returns_chronological_array
    attempts = @mgmt.deliveries.get_attempts(@workspace_id, "del_fixture_002")
    assert_kind_of Array, attempts
    assert_equal 3, attempts.length
    assert_equal 1, attempts[0]["attemptNumber"]
    assert_equal 2, attempts[1]["attemptNumber"]
    assert_equal 3, attempts[2]["attemptNumber"]
    assert_equal 502, attempts[0]["responseStatusCode"]
  end

  def test_deliveries_get_raises_404_for_unknown_id
    err = assert_raises(Nahook::APIError) do
      @mgmt.deliveries.get(@workspace_id, "del_does_not_exist_anywhere")
    end
    assert_equal 404, err.status
  end

  # -- auth error ----------------------------------------------------------

  def test_invalid_token_returns_401
    bad_mgmt = Nahook::Management.new("nhm_invalid_token_000", base_url: @api_url)

    err = assert_raises(Nahook::APIError) do
      bad_mgmt.endpoints.list(@workspace_id)
    end
    assert_equal 401, err.status
    assert err.auth_error?, "expected auth_error? to be true"
  end
end
