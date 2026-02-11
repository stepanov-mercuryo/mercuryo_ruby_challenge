# frozen_string_literal: true

module Services
  module Errors
    class BaseError < StandardError
      attr_reader :http_status, :error_code

      def initialize(message, http_status:, error_code:)
        super(message)
        @http_status = http_status
        @error_code = error_code
      end
    end

    class ValidationError < BaseError
      def initialize(message)
        super(message, http_status: 422, error_code: 'validation_error')
      end
    end

    class NotFoundError < BaseError
      def initialize(message)
        super(message, http_status: 404, error_code: 'not_found')
      end
    end

    class ConflictError < BaseError
      def initialize(message)
        super(message, http_status: 409, error_code: 'conflict')
      end
    end

    class InsufficientFundsError < BaseError
      def initialize(message = 'Insufficient funds')
        super(message, http_status: 409, error_code: 'insufficient_funds')
      end
    end
  end
end
