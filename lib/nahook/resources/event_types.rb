# frozen_string_literal: true

require "cgi"

module Nahook
  module Resources
    # Resource for managing event types via the Management API.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #   mgmt.event_types.list("ws_abc123")
    #   mgmt.event_types.create("ws_abc123", name: "order.paid")
    class EventTypes
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # List all event types in a workspace.
      #
      # @param workspace_id [String] the workspace public ID
      # @return [Hash] response with "data" key containing an array of event types
      def list(workspace_id)
        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/event-types"
        )
        { "data" => data }
      end

      # Create a new event type.
      #
      # @param workspace_id [String] the workspace public ID
      # @param name [String] the event type name (e.g. "order.paid")
      # @param description [String, nil] human-readable description
      # @return [Hash] the created event type
      def create(workspace_id, name:, description: nil)
        body = { "name" => name }
        body["description"] = description if description

        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/event-types",
          body: body
        )
      end

      # Get a single event type by ID.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the event type public ID
      # @return [Hash] the event type
      def get(workspace_id, id)
        @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/event-types/#{e(id)}"
        )
      end

      # Update an existing event type.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the event type public ID
      # @param description [String, nil] updated description
      # @return [Hash] the updated event type
      def update(workspace_id, id, description: nil)
        body = {}
        body["description"] = description unless description.nil?

        @http.request(
          method: :patch,
          path: "/management/v1/workspaces/#{e(workspace_id)}/event-types/#{e(id)}",
          body: body
        )
      end

      # Delete an event type.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the event type public ID
      # @return [nil]
      def delete(workspace_id, id)
        @http.request(
          method: :delete,
          path: "/management/v1/workspaces/#{e(workspace_id)}/event-types/#{e(id)}"
        )
      end

      private

      def e(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
