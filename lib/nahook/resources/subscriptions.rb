# frozen_string_literal: true

module Nahook
  module Resources
    # Resource for managing endpoint subscriptions via the Management API.
    #
    # Subscriptions link event types to endpoints, controlling which
    # events are delivered to which endpoint.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #   mgmt.subscriptions.list("ws_abc123", "ep_def456")
    #   mgmt.subscriptions.create("ws_abc123", "ep_def456", event_type_id: "evt_ghi789")
    class Subscriptions
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # List subscriptions for an endpoint.
      #
      # @param workspace_id [String] the workspace public ID
      # @param endpoint_id [String] the endpoint public ID
      # @return [Hash] response with "data" key containing an array of subscriptions
      def list(workspace_id, endpoint_id)
        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(endpoint_id)}/subscriptions"
        )
        { "data" => data }
      end

      # Create a subscription linking an event type to an endpoint.
      #
      # @param workspace_id [String] the workspace public ID
      # @param endpoint_id [String] the endpoint public ID
      # @param event_type_id [String] the event type public ID to subscribe to
      # @return [Hash] the created subscription
      def create(workspace_id, endpoint_id, event_type_id:)
        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(endpoint_id)}/subscriptions",
          body: { "eventTypeId" => event_type_id }
        )
      end

      # Delete a subscription.
      #
      # @param workspace_id [String] the workspace public ID
      # @param endpoint_id [String] the endpoint public ID
      # @param event_type_id [String] the event type public ID to unsubscribe
      # @return [nil]
      def delete(workspace_id, endpoint_id, event_type_id)
        @http.request(
          method: :delete,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(endpoint_id)}/subscriptions/#{e(event_type_id)}"
        )
      end

      private

      def e(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
