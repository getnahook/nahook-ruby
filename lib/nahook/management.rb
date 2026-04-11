# frozen_string_literal: true

module Nahook
  # Client for the Nahook Management API.
  #
  # Provides programmatic access to manage workspaces, endpoints, event types,
  # applications, subscriptions, and portal sessions. Intended for server-side
  # use with a management token.
  #
  # Unlike {Client}, the Management client does not support retries --
  # management operations are not idempotent by default.
  #
  # @example
  #   mgmt = Nahook::Management.new("nhm_your_token")
  #
  #   # List endpoints
  #   result = mgmt.endpoints.list("ws_abc123")
  #   result["data"].each { |ep| puts ep["url"] }
  #
  #   # Create an endpoint
  #   endpoint = mgmt.endpoints.create("ws_abc123",
  #     url: "https://example.com/webhook",
  #     description: "Production webhook"
  #   )
  class Management
    # @return [Resources::Endpoints]
    attr_reader :endpoints

    # @return [Resources::EventTypes]
    attr_reader :event_types

    # @return [Resources::Applications]
    attr_reader :applications

    # @return [Resources::Subscriptions]
    attr_reader :subscriptions

    # @return [Resources::PortalSessions]
    attr_reader :portal_sessions

    # @return [Resources::Environments]
    attr_reader :environments

    # @param token [String] management token (must start with "nhm_")
    # @param base_url [String] API base URL
    # @param timeout_ms [Integer] request timeout in milliseconds (default: 30000)
    # @raise [ArgumentError] if the token does not start with "nhm_"
    def initialize(token, base_url: HttpClient::DEFAULT_BASE_URL, timeout_ms: HttpClient::DEFAULT_TIMEOUT_MS)
      unless token.start_with?("nhm_")
        raise ArgumentError, "Invalid management token: must start with 'nhm_'"
      end

      http = HttpClient.new(token: token, base_url: base_url, timeout_ms: timeout_ms)

      @endpoints       = Resources::Endpoints.new(http)
      @event_types     = Resources::EventTypes.new(http)
      @applications    = Resources::Applications.new(http)
      @subscriptions   = Resources::Subscriptions.new(http)
      @portal_sessions = Resources::PortalSessions.new(http)
      @environments    = Resources::Environments.new(http)
    end
  end
end
