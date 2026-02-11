# frozen_string_literal: true

require 'grape'
require 'bigdecimal'
require 'securerandom'
require_relative '../config/db'

module Controllers
  class ApiController < Grape::API
    STATUS_PENDING = 'pending'
    STATUS_COMPLETED = 'completed'
    STATUS_CANCELLED = 'cancelled'

    TYPE_DEPOSIT = 'deposit'
    TYPE_WITHDRAWAL = 'withdrawal'

    format :json
    default_format :json

    rescue_from Sequel::UniqueConstraintViolation do
      error!({ error: 'uuid_conflict', message: 'UUID is already used by another transaction' }, 409)
    end

    rescue_from Sequel::DatabaseConnectionError, Sequel::DatabaseError do
      error!({ error: 'database_error', message: 'Database connection failed' }, 503)
    end

    helpers do
      def normalize_currency(value)
        currency = value.to_s.strip.upcase
        error!({ error: 'invalid_currency', message: 'Currency is required' }, 422) if currency.empty?
        currency
      end

      def normalize_uuid(value)
        uuid = value.to_s.strip
        return nil if uuid.empty?

        uuid
      end

      def normalize_amount(value, allow_zero: false)
        amount =
          begin
            BigDecimal(value.to_s).round(2)
          rescue ArgumentError
            nil
          end

        if amount.nil? || (!allow_zero && amount <= 0) || (allow_zero && amount < 0)
          error!({ error: 'invalid_amount', message: 'Amount must be positive' }, 422)
        end

        amount
      end

      def amount_to_s(value)
        format('%.2f', BigDecimal(value.to_s))
      end

      def serialize_account(account)
        {
          id: account[:id],
          balance: amount_to_s(account[:balance]),
          currency: account[:currency],
          created_at: account[:created_at],
          updated_at: account[:updated_at]
        }
      end

      def serialize_transaction(transaction)
        {
          id: transaction[:id],
          account_id: transaction[:account_id],
          currency: transaction[:currency],
          amount: amount_to_s(transaction[:amount]),
          status: transaction[:status],
          uuid: transaction[:uuid],
          transaction_type: transaction[:transaction_type],
          created_at: transaction[:created_at],
          updated_at: transaction[:updated_at]
        }
      end

      def find_account!(account_id, for_update: false)
        dataset = DB[:accounts].where(id: account_id.to_i)
        dataset = dataset.for_update if for_update
        account = dataset.first
        error!({ error: 'account_not_found', message: 'Account not found' }, 404) unless account
        account
      end

      def find_transaction_by_uuid!(uuid, for_update: false)
        dataset = DB[:transactions].where(uuid: uuid)
        dataset = dataset.for_update if for_update
        transaction = dataset.first
        error!({ error: 'transaction_not_found', message: 'Transaction not found' }, 404) unless transaction
        transaction
      end

      def ensure_currency_match!(account_currency, request_currency)
        return account_currency if request_currency.nil?

        currency = normalize_currency(request_currency)
        if currency != account_currency
          error!({ error: 'currency_mismatch', message: 'Currency does not match account currency' }, 422)
        end

        currency
      end

      def verify_existing_transaction!(transaction, account_id:, currency:, amount:, transaction_type:)
        expected_amount = transaction_type == TYPE_WITHDRAWAL ? -amount : amount
        matches = transaction[:account_id] == account_id &&
          transaction[:currency] == currency &&
          transaction[:transaction_type] == transaction_type &&
          BigDecimal(transaction[:amount].to_s) == expected_amount

        return if matches

        error!({ error: 'uuid_conflict', message: 'UUID is already used by another transaction' }, 409)
      end

      def persist_transaction!(account_id:, currency:, amount:, status:, transaction_type:, uuid:)
        now = Time.now.utc
        DB[:transactions].insert(
          account_id: account_id,
          currency: currency,
          amount: amount,
          status: status,
          uuid: uuid,
          transaction_type: transaction_type,
          created_at: now,
          updated_at: now
        )
      end

      def reserve_withdrawal!(account_id, amount, currency, provided_uuid = nil)
        DB.transaction do
          account = find_account!(account_id, for_update: true)
          tx_currency = ensure_currency_match!(account[:currency], currency)
          uuid = provided_uuid || SecureRandom.uuid

          existing = DB[:transactions].where(uuid: uuid).for_update.first
          if existing
            verify_existing_transaction!(
              existing,
              account_id: account[:id],
              currency: tx_currency,
              amount: amount,
              transaction_type: TYPE_WITHDRAWAL
            )
            return [200, serialize_transaction(existing)]
          end

          if BigDecimal(account[:balance].to_s) < amount
            error!({ error: 'insufficient_funds', message: 'Insufficient funds' }, 422)
          end

          now = Time.now.utc
          DB[:accounts].where(id: account[:id]).update(
            balance: BigDecimal(account[:balance].to_s) - amount,
            updated_at: now
          )

          transaction_id = persist_transaction!(
            account_id: account[:id],
            currency: tx_currency,
            amount: -amount,
            status: STATUS_PENDING,
            transaction_type: TYPE_WITHDRAWAL,
            uuid: uuid
          )

          transaction = DB[:transactions].where(id: transaction_id).first
          [201, serialize_transaction(transaction)]
        end
      end

      def confirm_withdrawal!(uuid)
        DB.transaction do
          transaction = find_transaction_by_uuid!(uuid, for_update: true)
          if transaction[:transaction_type] != TYPE_WITHDRAWAL
            error!({ error: 'invalid_transaction_type', message: 'Only withdrawal can be confirmed' }, 422)
          end

          case transaction[:status]
          when STATUS_PENDING
            now = Time.now.utc
            DB[:transactions].where(id: transaction[:id]).update(status: STATUS_COMPLETED, updated_at: now)
            transaction = DB[:transactions].where(id: transaction[:id]).first
          when STATUS_CANCELLED
            error!({ error: 'invalid_status_transition', message: 'Cancelled withdrawal cannot be confirmed' }, 409)
          end

          serialize_transaction(transaction)
        end
      end

      def cancel_withdrawal!(uuid)
        DB.transaction do
          transaction = find_transaction_by_uuid!(uuid, for_update: true)
          if transaction[:transaction_type] != TYPE_WITHDRAWAL
            error!({ error: 'invalid_transaction_type', message: 'Only withdrawal can be cancelled' }, 422)
          end

          case transaction[:status]
          when STATUS_PENDING
            account = find_account!(transaction[:account_id], for_update: true)
            refund = -BigDecimal(transaction[:amount].to_s)
            now = Time.now.utc
            DB[:accounts].where(id: account[:id]).update(
              balance: BigDecimal(account[:balance].to_s) + refund,
              updated_at: now
            )
            DB[:transactions].where(id: transaction[:id]).update(status: STATUS_CANCELLED, updated_at: now)
            transaction = DB[:transactions].where(id: transaction[:id]).first
          when STATUS_COMPLETED
            error!({ error: 'invalid_status_transition', message: 'Completed withdrawal cannot be cancelled' }, 409)
          end

          serialize_transaction(transaction)
        end
      end
    end

    get :health do
      DB.run('SELECT 1')
      { status: 'ok' }
    end

    resource :accounts do
      desc 'Create account'
      params do
        requires :currency, type: String
        optional :balance, type: BigDecimal
      end
      post do
        currency = normalize_currency(params[:currency])
        balance = params[:balance].nil? ? BigDecimal('0') : normalize_amount(params[:balance], allow_zero: true)
        now = Time.now.utc

        account_id = DB[:accounts].insert(
          balance: balance,
          currency: currency,
          created_at: now,
          updated_at: now
        )

        status 201
        serialize_account(DB[:accounts].where(id: account_id).first)
      end

      route_param :id, type: Integer do
        get do
          serialize_account(find_account!(params[:id]))
        end

        params do
          optional :limit, type: Integer, default: 100
        end
        get :transactions do
          limit = [params[:limit], 1].max
          limit = 1000 if limit > 1000

          find_account!(params[:id])
          transactions = DB[:transactions]
            .where(account_id: params[:id])
            .order(Sequel.desc(:id))
            .limit(limit)
            .all

          { transactions: transactions.map { |tx| serialize_transaction(tx) } }
        end

        desc 'Deposit funds'
        params do
          requires :amount, type: BigDecimal
          optional :currency, type: String
          optional :uuid, type: String
        end
        post :deposit do
          amount = normalize_amount(params[:amount])
          provided_uuid = normalize_uuid(params[:uuid])

          code, body = DB.transaction do
            account = find_account!(params[:id], for_update: true)
            currency = ensure_currency_match!(account[:currency], params[:currency])
            uuid = provided_uuid || SecureRandom.uuid

            existing = DB[:transactions].where(uuid: uuid).for_update.first
            if existing
              verify_existing_transaction!(
                existing,
                account_id: account[:id],
                currency: currency,
                amount: amount,
                transaction_type: TYPE_DEPOSIT
              )
              [200, serialize_transaction(existing)]
            else
              now = Time.now.utc
              DB[:accounts].where(id: account[:id]).update(
                balance: BigDecimal(account[:balance].to_s) + amount,
                updated_at: now
              )

              transaction_id = persist_transaction!(
                account_id: account[:id],
                currency: currency,
                amount: amount,
                status: STATUS_COMPLETED,
                transaction_type: TYPE_DEPOSIT,
                uuid: uuid
              )

              [201, serialize_transaction(DB[:transactions].where(id: transaction_id).first)]
            end
          end

          status code
          body
        end

        desc 'Reserve withdrawal (create pending transaction)'
        params do
          requires :amount, type: BigDecimal
          optional :currency, type: String
          optional :uuid, type: String
        end
        post :withdrawals do
          amount = normalize_amount(params[:amount])
          provided_uuid = normalize_uuid(params[:uuid])
          code, body = reserve_withdrawal!(params[:id], amount, params[:currency], provided_uuid)
          status code
          body
        end

        # Alias for clients that use singular naming.
        params do
          requires :amount, type: BigDecimal
          optional :currency, type: String
          optional :uuid, type: String
        end
        post :withdraw do
          amount = normalize_amount(params[:amount])
          provided_uuid = normalize_uuid(params[:uuid])
          code, body = reserve_withdrawal!(params[:id], amount, params[:currency], provided_uuid)
          status code
          body
        end
      end
    end

    resource :transactions do
      route_param :uuid, type: String do
        get do
          serialize_transaction(find_transaction_by_uuid!(params[:uuid]))
        end

        post :confirm do
          confirm_withdrawal!(params[:uuid])
        end

        post :cancel do
          cancel_withdrawal!(params[:uuid])
        end
      end
    end

    resource :withdrawals do
      route_param :uuid, type: String do
        post :confirm do
          confirm_withdrawal!(params[:uuid])
        end

        post :cancel do
          cancel_withdrawal!(params[:uuid])
        end
      end
    end
  end
end
