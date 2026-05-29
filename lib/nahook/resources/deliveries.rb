# frozen_string_literal: true

require "cgi"

module Nahook
  # Generic paginated result returned by cursor-paginated list endpoints.
  #
  # @!attribute [rw] data
  #   @return [Array<Hash>] the page of results
  # @!attribute [rw] next_cursor
  #   @return [String, nil] opaque cursor for the next page, or nil if this is
  #     the last page. Pass back verbatim into the next list call.
  PaginatedResult = Struct.new(:data, :next_cursor)

  module Resources
    # Read access to a workspace's webhook deliveries via the Management API.
    #
    # All methods are paginated or single-resource reads -- this resource has
    # no create/update/delete operations. Deliveries are produced by the
    # ingestion path and consumed by the worker; the Management API exposes
    # only their observable state.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #
    #   # List a page of deliveries for an endpoint
    #   page = mgmt.deliveries.list("ws_abc123", "ep_def456", limit: 50)
    #   page.data.each { |d| puts d["id"] }
    #   next_page = mgmt.deliveries.list("ws_abc123", "ep_def456", cursor: page.next_cursor)
    #
    #   # Fetch a single delivery (metadata only)
    #   delivery = mgmt.deliveries.get("ws_abc123", "del_xyz")
    #
    #   # Fetch with payload envelope
    #   delivery = mgmt.deliveries.get("ws_abc123", "del_xyz", include_payload: true)
    #
    #   # List attempts (chronological order)
    #   attempts = mgmt.deliveries.get_attempts("ws_abc123", "del_xyz")
    class Deliveries
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # List deliveries for an endpoint, newest-first, with opaque cursor pagination.
      #
      # @param workspace_id [String] the workspace public ID
      # @param endpoint_id [String] the endpoint public ID
      # @param limit [Integer, nil] page size, server-capped (default 50, max 100)
      # @param cursor [String, nil] opaque cursor from a previous response's
      #   {PaginatedResult#next_cursor}. Pass through unchanged.
      # @param status [String, nil] filter by delivery status. One of:
      #   "pending", "delivering", "delivered", "scheduled_retry", "failed",
      #   "dead_letter".
      # @return [PaginatedResult] paginated result whose +data+ is an array of
      #   delivery hashes and +next_cursor+ is a String or nil.
      def list(workspace_id, endpoint_id, limit: nil, cursor: nil, status: nil)
        raw = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/endpoints/#{e(endpoint_id)}/deliveries",
          query: { "limit" => limit, "cursor" => cursor, "status" => status }
        )
        PaginatedResult.new(raw["deliveries"] || [], raw["nextCursor"])
      end

      # Get a single delivery's metadata, optionally including the payload envelope.
      #
      # When +include_payload+ is true, the response includes a "payload"
      # envelope whose "status" is one of: "available", "forbidden",
      # "processing", "not_found", "error". The endpoint stays 200 for all 5 --
      # the envelope status carries access-level reality. This method does NOT
      # raise on "forbidden"/"processing"/"not_found"/"error".
      #
      # @param workspace_id [String] the workspace public ID
      # @param delivery_id [String] the delivery public ID (starts with "del_")
      # @param include_payload [Boolean] if true, sends ?include=payload and
      #   the response includes a "payload" envelope (default false).
      # @return [Hash] the delivery; includes a "payload" envelope when
      #   +include_payload+ is true.
      def get(workspace_id, delivery_id, include_payload: false)
        query = include_payload ? { "include" => "payload" } : nil
        @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/deliveries/#{e(delivery_id)}",
          query: query
        )
      end

      # List delivery attempts for a single delivery, in chronological order
      # (oldest first).
      #
      # The attempt "status" field is an opaque string ("failed", "success",
      # etc.) -- treat it as a string, not an enum.
      #
      # @param workspace_id [String] the workspace public ID
      # @param delivery_id [String] the delivery public ID (starts with "del_")
      # @return [Array<Hash>] attempts in chronological order
      def get_attempts(workspace_id, delivery_id)
        @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/deliveries/#{e(delivery_id)}/attempts"
        )
      end

      private

      def e(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
