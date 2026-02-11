# frozen_string_literal: true

module Services
  module Transactions
    class Deposit
      def self.call(account_id:, uuid:, currency:, amount:)
        new(account_id: account_id, uuid: uuid, currency: currency, amount: amount).call
      end

      def initialize(account_id:, uuid:, currency:, amount:)
        @account_id = Services::Validators.normalize_account_id!(account_id)
        @uuid = Services::Validators.normalize_uuid!(uuid)
        @currency = Services::Validators.normalize_currency!(currency)
        @amount = Services::Validators.parse_positive_amount!(amount)
      end

      def call
        DB.transaction do
          account = Account.where(id: @account_id).for_update.first
          raise Services::Errors::NotFoundError, 'account not found' unless account

          ensure_currency_match!(account)

          existing = Transaction.where(uuid: @uuid).first
          if existing
            Services::Idempotency.ensure_matching_request!(
              transaction: existing,
              account_id: account.id,
              currency: @currency,
              amount: @amount,
              transaction_type: 'deposit'
            )
            return build_result(existing, account, created: false)
          end

          new_balance = account.balance + @amount
          Services::Validators.ensure_money_range!(new_balance, field_name: 'balance')

          account.update(balance: new_balance)
          transaction = Transaction.create(
            account_id: account.id,
            currency: @currency,
            amount: @amount,
            status: 'completed',
            uuid: @uuid,
            transaction_type: 'deposit'
          )
          build_result(transaction, account, created: true)
        end
      rescue Sequel::UniqueConstraintViolation
        fetch_existing_idempotent_result
      end

      private

      def ensure_currency_match!(account)
        if account.currency != @currency
          raise Services::Errors::ConflictError, 'transaction currency must match account currency'
        end
      end

      def fetch_existing_idempotent_result
        transaction = Transaction.where(uuid: @uuid).first
        raise Services::Errors::ConflictError, 'uuid conflict' unless transaction

        Services::Idempotency.ensure_matching_request!(
          transaction: transaction,
          account_id: @account_id,
          currency: @currency,
          amount: @amount,
          transaction_type: 'deposit'
        )

        account = Account[transaction.account_id]
        build_result(transaction, account, created: false)
      end

      def build_result(transaction, account, created:)
        {
          transaction: transaction,
          account: account,
          created: created
        }
      end
    end
  end
end
