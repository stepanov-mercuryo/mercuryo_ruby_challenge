# frozen_string_literal: true

module Services
  module Transactions
    class CancelWithdrawal
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
            raise Services::Errors::ConflictError, "cannot cancel transaction in #{transaction.status} status"
          end

          account = Account.where(id: transaction.account_id).for_update.first
          account.update(balance: account.balance + transaction.amount.abs)
          transaction.update(status: 'cancelled')

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
