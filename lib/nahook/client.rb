# frozen_string_literal: true

require "securerandom"

module Nahook
  # Client for sending webhook payloads through the Nahook ingestion API.
  #
  # Supports sending to specific endpoints, fan-out by event type,
  # and batch operations. Includes configurable retry with exponential backoff.
  #
  # @example Basic usage
  #   client = Nahook::Client.new("nhk_your_api_key")
  #   client.send("ep_abc123", payload: { order_id: "12345" })
  #
  # @example With options
  #   client = Nahook::Client.new("nhk_your_api_key",
  #     base_url: "https://custom.nahook.com",
  #     timeout: 15,
  #     retries: 3
  #   )
  class Client
    # @param api_key [String] API key (must start with "nhk_")
    # @param base_url [String] API base URL
    # @param timeout [Integer] request timeout in seconds
    # @param retries [Integer] number of retry attempts for retryable errors
    # @raise [ArgumentError] if the API key does not start with "nhk_"
    def initialize(api_key, base_url: HttpClient::DEFAULT_BASE_URL, timeout: HttpClient::DEFAULT_TIMEOUT, retries: 0)
      unless api_key.start_with?("nhk_")
        raise ArgumentError, "Invalid API key: must start with 'nhk_'"
      end

      @http = HttpClient.new(
        token: api_key,
        base_url: base_url,
        timeout: timeout,
        retries: retries
      )
    end

    # Send a payload to a specific endpoint.
    #
    # @param endpoint_id [String] the endpoint public ID (e.g. "ep_abc123")
    # @param payload [Hash] the webhook payload
    # @param idempotency_key [String, nil] optional idempotency key (auto-generated if omitted)
    # @return [Hash] response with "deliveryId", "idempotencyKey", and "status" keys
    # @raise [APIError] on API error responses
    # @raise [NetworkError] on connection failures
    # @raise [TimeoutError] on request timeout
    def send(endpoint_id, payload:, idempotency_key: nil)
      key = idempotency_key || SecureRandom.uuid

      @http.request(
        method: :post,
        path: "/api/ingest/#{CGI.escape(endpoint_id)}",
        body: {
          "payload" => payload,
          "idempotencyKey" => key
        }
      )
    end

    # Fan-out a payload by event type to all subscribed endpoints.
    #
    # @param event_type [String] the event type name (e.g. "order.paid")
    # @param payload [Hash] the webhook payload
    # @param metadata [Hash, nil] optional metadata key-value pairs
    # @return [Hash] response with "eventTypeId", "deliveryIds", and "status" keys
    # @raise [APIError] on API error responses
    def trigger(event_type, payload:, metadata: nil)
      body = { "payload" => payload }
      body["metadata"] = metadata if metadata

      @http.request(
        method: :post,
        path: "/api/ingest/event/#{CGI.escape(event_type)}",
        body: body
      )
    end

    # Batch send to multiple specific endpoints (max 20 items).
    #
    # @param items [Array<Hash>] list of items, each with :endpoint_id, :payload, and optional :idempotency_key
    # @return [Hash] response with "items" key containing per-item results
    # @raise [APIError] on API error responses
    #
    # @example
    #   client.send_batch([
    #     { endpoint_id: "ep_abc", payload: { order: 1 } },
    #     { endpoint_id: "ep_def", payload: { order: 2 }, idempotency_key: "key-2" }
    #   ])
    def send_batch(items)
      mapped = items.map do |item|
        entry = {
          "endpointId" => item[:endpoint_id] || item["endpoint_id"],
          "payload" => item[:payload] || item["payload"]
        }
        key = item[:idempotency_key] || item["idempotency_key"]
        entry["idempotencyKey"] = key if key
        entry
      end

      @http.request(
        method: :post,
        path: "/api/ingest/batch",
        body: { "items" => mapped }
      )
    end

    # Batch fan-out by event types (max 20 items).
    #
    # @param items [Array<Hash>] list of items, each with :event_type, :payload, and optional :metadata
    # @return [Hash] response with "items" key containing per-item results
    # @raise [APIError] on API error responses
    #
    # @example
    #   client.trigger_batch([
    #     { event_type: "order.paid", payload: { order_id: "123" } },
    #     { event_type: "user.created", payload: { user_id: "456" } }
    #   ])
    def trigger_batch(items)
      mapped = items.map do |item|
        entry = {
          "eventType" => item[:event_type] || item["event_type"],
          "payload" => item[:payload] || item["payload"]
        }
        meta = item[:metadata] || item["metadata"]
        entry["metadata"] = meta if meta
        entry
      end

      @http.request(
        method: :post,
        path: "/api/ingest/event/batch",
        body: { "items" => mapped }
      )
    end
  end
end
