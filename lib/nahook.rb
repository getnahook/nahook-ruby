# frozen_string_literal: true

require_relative "nahook/version"
require_relative "nahook/errors"
require_relative "nahook/http_client"
require_relative "nahook/client"
require_relative "nahook/management"
require_relative "nahook/resources/endpoints"
require_relative "nahook/resources/event_types"
require_relative "nahook/resources/applications"
require_relative "nahook/resources/subscriptions"
require_relative "nahook/resources/portal_sessions"

# Official Ruby SDK for the Nahook webhook platform.
#
# Nahook provides two main entry points:
#
# - {Nahook::Client} for sending webhook payloads (ingestion API)
# - {Nahook::Management} for managing resources (management API)
#
# @example Sending a webhook
#   client = Nahook::Client.new("nhk_your_api_key")
#   client.send("ep_abc123", payload: { order_id: "12345" })
#
# @example Managing endpoints
#   mgmt = Nahook::Management.new("nhm_your_token")
#   mgmt.endpoints.list("ws_abc123")
module Nahook; end
