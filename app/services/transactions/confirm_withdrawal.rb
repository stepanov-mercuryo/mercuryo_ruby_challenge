# frozen_string_literal: true

module Services
  module Transactions
    class ConfirmWithdrawal
      def self.call(uuid:)
        new(uuid: uuid).call
      end

      def initialize(uuid:)
        @uuid = Services::Validators.normalize_uuid!(uuid)
      end

      def call
        DB.transaction do
          transaction = Transaction.where(uuid: @uuid, transaction_type: 'withdrawal').for_update.first
          raise Services::Errors::NotFoundError, 'withdrawal transaction not found' unless transaction

          if transaction.status != 'pending'
            raise Services::Errors::ConflictError, "cannot confirm transaction in #{transaction.status} status"
          end

          transaction.update(status: 'completed')
          account = Account[transaction.account_id]

          {
            transaction: transaction,
            account: account,
            created: false
          }
        end
      end
    end
  end
end
