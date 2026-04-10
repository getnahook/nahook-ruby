# frozen_string_literal: true

module Nahook
  module Resources
    # Resource for managing webhook endpoints via the Management API.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #   mgmt.endpoints.list("ws_abc123")
    #   mgmt.endpoints.create("ws_abc123", url: "https://example.com/webhook")
    class Endpoints
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # List all endpoints in a workspace.
      #
      # @param workspace_id [String] the workspace public ID
      # @return [Hash] response with "data" key containing an array of endpoints
      def list(workspace_id)
        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints"
        )
        { "data" => data }
      end

      # Create a new endpoint.
      #
      # @param workspace_id [String] the workspace public ID
      # @param url [String] the endpoint URL
      # @param type [String, nil] endpoint type ("webhook" or "slack")
      # @param description [String, nil] human-readable description
      # @param metadata [Hash, nil] arbitrary key-value metadata
      # @param config [Hash, nil] endpoint-specific configuration
      # @param auth_username [String, nil] basic auth username
      # @param auth_password [String, nil] basic auth password
      # @return [Hash] the created endpoint
      def create(workspace_id, url:, type: nil, description: nil, metadata: nil, config: nil,
                 auth_username: nil, auth_password: nil)
        body = { "url" => url }
        body["type"]         = type         if type
        body["description"]  = description  if description
        body["metadata"]     = metadata     if metadata
        body["config"]       = config       if config
        body["authUsername"]  = auth_username if auth_username
        body["authPassword"] = auth_password if auth_password

        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints",
          body: body
        )
      end

      # Get a single endpoint by ID.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the endpoint public ID
      # @return [Hash] the endpoint
      def get(workspace_id, id)
        @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(id)}"
        )
      end

      # Update an existing endpoint.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the endpoint public ID
      # @param url [String, nil] updated URL
      # @param description [String, nil] updated description
      # @param metadata [Hash, nil] updated metadata
      # @param is_active [Boolean, nil] whether the endpoint is active
      # @return [Hash] the updated endpoint
      def update(workspace_id, id, url: nil, description: nil, metadata: nil, is_active: nil)
        body = {}
        body["url"]         = url         unless url.nil?
        body["description"] = description unless description.nil?
        body["metadata"]    = metadata    unless metadata.nil?
        body["isActive"]    = is_active   unless is_active.nil?

        @http.request(
          method: :patch,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(id)}",
          body: body
        )
      end

      # Delete an endpoint.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the endpoint public ID
      # @return [nil]
      def delete(workspace_id, id)
        @http.request(
          method: :delete,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(id)}"
        )
      end

      private

      def e(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
