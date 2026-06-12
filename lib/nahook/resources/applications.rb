# frozen_string_literal: true

require "cgi"

module Nahook
  module Resources
    # Resource for managing applications via the Management API.
    #
    # Applications group endpoints for multi-tenant use cases.
    # Each application can have its own set of endpoints and a developer portal.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #   mgmt.applications.list("ws_abc123", limit: 10)
    #   mgmt.applications.create("ws_abc123", name: "Acme Corp")
    class Applications
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # List applications in a workspace with optional pagination.
      #
      # @param workspace_id [String] the workspace public ID
      # @param limit [Integer, nil] maximum number of results
      # @param offset [Integer, nil] number of results to skip
      # @return [Hash] response with "data" key containing an array of applications
      def list(workspace_id, limit: nil, offset: nil)
        query = {}
        query["limit"]  = limit  if limit
        query["offset"] = offset if offset

        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications",
          query: query.empty? ? nil : query
        )
        { "data" => data }
      end

      # Create a new application.
      #
      # @param workspace_id [String] the workspace public ID
      # @param name [String] the application name
      # @param external_id [String, nil] an external identifier for your system
      # @param metadata [Hash, nil] arbitrary key-value metadata
      # @param max_endpoints [Integer, nil] cap on how many endpoints this
      #   application may have (disabled endpoints count); 0 makes it
      #   read-only, nil (default) means unlimited
      # @param show_event_types [Boolean, nil] whether the Developer Portal
      #   exposes the event-type catalog (server defaults to true)
      # @return [Hash] the created application
      def create(workspace_id, name:, external_id: nil, metadata: nil, max_endpoints: nil, show_event_types: nil)
        body = { "name" => name }
        body["externalId"] = external_id if external_id
        body["metadata"]   = metadata    if metadata
        body["maxEndpoints"]   = max_endpoints    unless max_endpoints.nil?
        body["showEventTypes"] = show_event_types unless show_event_types.nil?

        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications",
          body: body
        )
      end

      # Get a single application by ID.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the application public ID
      # @return [Hash] the application
      def get(workspace_id, id)
        @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications/#{e(id)}"
        )
      end

      # Update an existing application.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the application public ID
      # @param name [String, nil] updated name
      # @param metadata [Hash, nil] updated metadata
      # @param max_endpoints [Integer, nil, UNSET] tri-state: leave as
      #   +UNSET+ (default) to keep the current cap, pass +nil+ to clear it
      #   (unlimited), or pass an Integer (>= 0) to set it
      # @param show_event_types [Boolean, UNSET] omitted when +UNSET+
      # @return [Hash] the updated application
      def update(workspace_id, id, name: nil, metadata: nil, max_endpoints: UNSET, show_event_types: UNSET)
        body = {}
        body["name"]     = name     unless name.nil?
        body["metadata"] = metadata unless metadata.nil?
        body["maxEndpoints"]   = max_endpoints    unless max_endpoints.equal?(UNSET)
        body["showEventTypes"] = show_event_types unless show_event_types.equal?(UNSET)

        @http.request(
          method: :patch,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications/#{e(id)}",
          body: body
        )
      end

      # Delete an application.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the application public ID
      # @return [nil]
      def delete(workspace_id, id)
        @http.request(
          method: :delete,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications/#{e(id)}"
        )
      end

      # List endpoints belonging to an application.
      #
      # @param workspace_id [String] the workspace public ID
      # @param app_id [String] the application public ID
      # @return [Hash] response with "data" key containing an array of endpoints
      def list_endpoints(workspace_id, app_id)
        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications/#{e(app_id)}/endpoints"
        )
        { "data" => data }
      end

      # Create an endpoint within an application.
      #
      # @param workspace_id [String] the workspace public ID
      # @param app_id [String] the application public ID
      # @param url [String] the endpoint URL
      # @param type [String, nil] endpoint type ("webhook" or "slack")
      # @param description [String, nil] human-readable description
      # @param metadata [Hash, nil] arbitrary key-value metadata
      # @param config [Hash, nil] endpoint-specific configuration
      # @return [Hash] the created endpoint
      def create_endpoint(workspace_id, app_id, url:, type: nil, description: nil, metadata: nil, config: nil)
        body = { "url" => url }
        body["type"]        = type        if type
        body["description"] = description if description
        body["metadata"]    = metadata    if metadata
        body["config"]      = config      if config

        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications/#{e(app_id)}/endpoints",
          body: body
        )
      end

      private

      def e(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
