# frozen_string_literal: true

require "cgi"

module Nahook
  module Resources
    # Resource for managing environments via the Management API.
    #
    # @example
    #   mgmt = Nahook::Management.new("nhm_token")
    #   mgmt.environments.list("ws_abc123")
    #   mgmt.environments.create("ws_abc123", name: "Staging", slug: "staging")
    class Environments
      # @api private
      # @param http [Nahook::HttpClient]
      def initialize(http)
        @http = http
      end

      # List all environments in a workspace.
      #
      # @param workspace_id [String] the workspace public ID
      # @return [Hash] response with "data" key containing an array of environments
      def list(workspace_id)
        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments"
        )
        { "data" => data }
      end

      # Create a new environment.
      #
      # @param workspace_id [String] the workspace public ID
      # @param name [String] the environment name
      # @param slug [String] the environment slug
      # @return [Hash] the created environment
      def create(workspace_id, name:, slug:)
        @http.request(
          method: :post,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments",
          body: { "name" => name, "slug" => slug }
        )
      end

      # Get a single environment by ID.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the environment ID
      # @return [Hash] the environment
      def get(workspace_id, id)
        @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments/#{e(id)}"
        )
      end

      # Update an existing environment.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the environment ID
      # @param name [String, nil] the updated name
      # @return [Hash] the updated environment
      def update(workspace_id, id, name: nil)
        body = {}
        body["name"] = name unless name.nil?
        @http.request(
          method: :patch,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments/#{e(id)}",
          body: body
        )
      end

      # Delete an environment.
      #
      # @param workspace_id [String] the workspace public ID
      # @param id [String] the environment ID
      # @return [nil]
      def delete(workspace_id, id)
        @http.request(
          method: :delete,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments/#{e(id)}"
        )
      end

      # List event type visibility for an environment.
      #
      # @param workspace_id [String] the workspace public ID
      # @param env_id [String] the environment ID
      # @return [Hash] response with "data" key containing an array of event type visibility entries
      def list_event_type_visibility(workspace_id, env_id)
        data = @http.request(
          method: :get,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments/#{e(env_id)}/event-types"
        )
        { "data" => data }
      end

      # Set event type visibility for an environment.
      #
      # @param workspace_id [String] the workspace public ID
      # @param env_id [String] the environment ID
      # @param event_type_id [String] the event type ID
      # @param published [Boolean] whether the event type is published in this environment
      # @return [Hash] the updated visibility entry
      def set_event_type_visibility(workspace_id, env_id, event_type_id, published:)
        @http.request(
          method: :put,
          path: "/management/v1/workspaces/#{e(workspace_id)}/environments/#{e(env_id)}/event-types/#{e(event_type_id)}/visibility",
          body: { "published" => published }
        )
      end

      private

      def e(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
