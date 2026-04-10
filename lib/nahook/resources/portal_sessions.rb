# frozen_string_literal: true

module Nahook
  module Resources
    # Resource for creating developer portal sessions via the Management API.
    #
    # Portal sessions generate short-lived URLs that grant your customers
    # access to a self-service endpoint management portal.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #   session = mgmt.portal_sessions.create("ws_abc123", "app_def456")
    #   puts session["url"] # => "https://portal.nahook.com/..."
    class PortalSessions
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # Create a portal session for an application.
      #
      # @param workspace_id [String] the workspace public ID
      # @param app_id [String] the application public ID
      # @param metadata [Hash, nil] optional metadata for the session
      # @return [Hash] session with "url", "code", and "expiresAt" keys
      def create(workspace_id, app_id, metadata: nil)
        body = {}
        body["metadata"] = metadata if metadata

        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/applications/#{e(app_id)}/portal",
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
