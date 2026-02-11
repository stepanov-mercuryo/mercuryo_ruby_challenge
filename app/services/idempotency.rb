# frozen_string_literal: true

module Services
  module Idempotency
    module_function

    def ensure_matching_request!(transaction:, account_id:, currency:, amount:, transaction_type:)
      if transaction.account_id != account_id ||
         transaction.currency != currency ||
         transaction.amount != amount ||
         transaction.transaction_type != transaction_type
        raise Services::Errors::ConflictError, 'uuid is already used for a different request'
      end
    end
  end
end
