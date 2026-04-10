# frozen_string_literal: true

module Nahook
  # Base error for all Nahook SDK errors.
  class Error < StandardError; end

  # Raised when the Nahook API returns an error response (4xx/5xx).
  #
  # @example Handling an API error
  #   begin
  #     client.send("ep_123", payload: { order: 1 })
  #   rescue Nahook::APIError => e
  #     puts e.status     # => 404
  #     puts e.code       # => "not_found"
  #     puts e.retryable? # => false
  #   end
  class APIError < Error
    # @return [Integer] HTTP status code
    attr_reader :status

    # @return [String] machine-readable error code from the API
    attr_reader :code

    # @return [Integer, nil] seconds the client should wait before retrying
    attr_reader :retry_after

    # @param status [Integer] HTTP status code
    # @param code [String] machine-readable error code
    # @param message [String] human-readable error message
    # @param retry_after [Integer, nil] Retry-After header value in seconds
    def initialize(status, code, message, retry_after = nil)
      @status = status
      @code = code
      @retry_after = retry_after
      super(message)
    end

    # Whether this error is safe to retry (5xx or 429).
    #
    # @return [Boolean]
    def retryable?
      status >= 500 || status == 429
    end

    # Whether this is an authentication or authorization error.
    #
    # @return [Boolean]
    def auth_error?
      status == 401 || (status == 403 && code == "token_disabled")
    end

    # Whether the requested resource was not found.
    #
    # @return [Boolean]
    def not_found?
      status == 404
    end

    # Whether the request was rate limited.
    #
    # @return [Boolean]
    def rate_limited?
      status == 429
    end

    # Whether the request failed validation.
    #
    # @return [Boolean]
    def validation_error?
      status == 400
    end
  end

  # Raised when a network-level failure occurs (no HTTP response received).
  class NetworkError < Error
    # @return [Exception] the underlying error that caused this failure
    attr_reader :original_error

    # @param original_error [Exception] the original exception
    def initialize(original_error)
      @original_error = original_error
      super("Network error: #{original_error.message}")
    end
  end

  # Raised when a request exceeds the configured timeout.
  class TimeoutError < Error
    # @return [Integer] the timeout in milliseconds
    attr_reader :timeout_ms

    # @param timeout_ms [Integer] the configured timeout in milliseconds
    def initialize(timeout_ms)
      @timeout_ms = timeout_ms
      super("Request timed out after #{timeout_ms}ms")
    end
  end
end
