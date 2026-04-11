# frozen_string_literal: true

require "faraday"
require "json"
require "cgi"

module Nahook
  # Low-level HTTP client used by both {Client} and {Management}.
  #
  # Handles request execution, retry logic with exponential backoff,
  # and error parsing. Not intended for direct use.
  #
  # @api private
  class HttpClient
    DEFAULT_BASE_URL  = "https://api.nahook.com"
    DEFAULT_TIMEOUT_MS = 30_000
    BASE_DELAY_MS     = 500
    MAX_DELAY_MS      = 10_000

    REGION_BASE_URLS = {
      "us" => "https://us.api.nahook.com",
      "eu" => "https://eu.api.nahook.com",
      "ap" => "https://ap.api.nahook.com",
    }.freeze

    # @api private
    def self.resolve_base_url(token)
      if (m = token.match(/\Anhk_([a-z]{2})_/))
        REGION_BASE_URLS[m[1]] || DEFAULT_BASE_URL
      else
        DEFAULT_BASE_URL
      end
    end

    # @param token [String] bearer token for authentication
    # @param base_url [String] API base URL
    # @param timeout_ms [Integer] request timeout in milliseconds (default: 30000)
    # @param retries [Integer] number of retry attempts for retryable errors
    def initialize(token:, base_url: DEFAULT_BASE_URL, timeout_ms: DEFAULT_TIMEOUT_MS, retries: 0)
      @token      = token
      @retries    = retries
      @timeout_ms = timeout_ms

      timeout_secs = timeout_ms / 1000.0
      @conn = Faraday.new(url: base_url.chomp("/")) do |f|
        f.options.timeout      = timeout_secs
        f.options.open_timeout = timeout_secs
        f.adapter Faraday.default_adapter
      end
    end

    # Execute an HTTP request with optional retry logic.
    #
    # @param method [Symbol] HTTP method (:get, :post, :patch, :delete)
    # @param path [String] request path (will be appended to base URL)
    # @param body [Hash, nil] request body (will be JSON-encoded)
    # @param query [Hash, nil] query parameters
    # @return [Hash, nil] parsed JSON response, or nil for 204
    # @raise [APIError] on 4xx/5xx responses
    # @raise [NetworkError] on connection failures
    # @raise [TimeoutError] on request timeout
    def request(method:, path:, body: nil, query: nil)
      execute_with_retry(method, path, body, query)
    end

    private

    def execute_with_retry(method, path, body, query)
      last_error = nil

      (0..@retries).each do |attempt|
        if attempt > 0
          retry_after_ms = last_error.is_a?(APIError) ? (last_error.retry_after || 0) * 1000 : nil
          delay = calculate_delay(attempt - 1, retry_after_ms)
          sleep(delay / 1000.0)
        end

        begin
          response = perform_request(method, path, body, query)

          unless response.success?
            error = parse_error(response)
            if attempt < @retries && retryable?(error)
              last_error = error
              next
            end
            raise error
          end

          return nil if response.status == 204
          return JSON.parse(response.body)

        rescue APIError
          raise

        rescue Faraday::TimeoutError => e
          last_error = TimeoutError.new(@timeout_ms)
          raise last_error unless attempt < @retries && retryable?(last_error)

        rescue Faraday::ConnectionFailed => e
          last_error = NetworkError.new(e)
          raise last_error unless attempt < @retries && retryable?(last_error)
        end
      end

      raise last_error
    end

    def perform_request(method, path, body, query)
      @conn.run_request(method, path, nil, request_headers(body)) do |req|
        req.body = JSON.generate(body) if body
        if query
          query.each do |key, value|
            req.params[key.to_s] = value.to_s unless value.nil?
          end
        end
      end
    end

    def request_headers(body)
      headers = {
        "Authorization" => "Bearer #{@token}",
        "Accept"        => "application/json",
        "User-Agent"    => "nahook-ruby/#{Nahook::VERSION}"
      }
      headers["Content-Type"] = "application/json" if body
      headers
    end

    def parse_error(response)
      retry_after = response.headers["retry-after"]
      retry_after_secs = retry_after ? retry_after.to_i : nil

      begin
        body = JSON.parse(response.body)
        code    = body.dig("error", "code") || "unknown"
        message = body.dig("error", "message") || response.reason_phrase || "Unknown error"
      rescue JSON::ParserError
        code    = "unknown"
        message = response.reason_phrase || "Unknown error"
      end

      APIError.new(response.status, code, message, retry_after_secs)
    end

    def calculate_delay(attempt, retry_after_ms = nil)
      if retry_after_ms && retry_after_ms > 0
        return retry_after_ms
      end

      exponential = [MAX_DELAY_MS, BASE_DELAY_MS * (2**attempt)].min
      exponential * rand
    end

    def retryable?(error)
      case error
      when APIError     then error.retryable?
      when NetworkError then true
      when TimeoutError then true
      else false
      end
    end
  end
end
