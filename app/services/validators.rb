# frozen_string_literal: true

require 'bigdecimal'

module Services
  module Validators
    CURRENCY_FORMAT = /\A[A-Z]{3}\z/.freeze
    AMOUNT_FORMAT = /\A\d+(?:\.\d{1,2})?\z/.freeze
    MAX_ABS_MONEY = BigDecimal('999999999999999999.99')

    module_function

    def normalize_account_id!(account_id)
      normalized = Integer(account_id)
      raise Services::Errors::ValidationError, 'account_id must be positive' if normalized <= 0

      normalized
    rescue ArgumentError, TypeError
      raise Services::Errors::ValidationError, 'account_id must be an integer'
    end

    def normalize_uuid!(uuid)
      normalized = uuid.to_s.strip
      raise Services::Errors::ValidationError, 'uuid is required' if normalized.empty?
      raise Services::Errors::ValidationError, 'uuid is too long' if normalized.length > 128

      normalized
    end

    def normalize_currency!(currency)
      normalized = currency.to_s.strip.upcase
      unless normalized.match?(CURRENCY_FORMAT)
        raise Services::Errors::ValidationError, 'currency must be a 3-letter ISO code'
      end

      normalized
    end

    def parse_positive_amount!(amount)
      amount_str = amount.to_s.strip
      unless amount_str.match?(AMOUNT_FORMAT)
        raise Services::Errors::ValidationError, 'amount must be a positive number with up to 2 decimals'
      end

      decimal = BigDecimal(amount_str)
      raise Services::Errors::ValidationError, 'amount must be greater than 0' if decimal <= 0
      ensure_money_range!(decimal, field_name: 'amount')

      decimal
    end

    def ensure_money_range!(value, field_name:)
      return if value.abs <= MAX_ABS_MONEY

      raise Services::Errors::ValidationError, "#{field_name} exceeds maximum supported value"
    end
  end
end
