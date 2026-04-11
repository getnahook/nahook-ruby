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
