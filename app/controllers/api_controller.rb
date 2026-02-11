# frozen_string_literal: true

require 'grape'
require 'time'
require 'bigdecimal'
require_relative '../boot'

module Controllers
  class ApiController < Grape::API
    prefix :api
    version 'v1', using: :path
    format :json

    helpers do
      def format_money(value)
        decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
        normalized = decimal.round(2).to_s('F')
        whole, fraction = normalized.split('.', 2)
        "#{whole}.#{fraction.to_s.ljust(2, '0')[0, 2]}"
      end

      def serialize_result(result)
        transaction = result.fetch(:transaction)
        account = result.fetch(:account)

        {
          transaction: {
            id: transaction.id,
            account_id: transaction.account_id,
            uuid: transaction.uuid,
            transaction_type: transaction.transaction_type,
            status: transaction.status,
            amount: format_money(transaction.amount),
            currency: transaction.currency,
            created_at: transaction.created_at.utc.iso8601,
            updated_at: transaction.updated_at.utc.iso8601
          },
          account: {
            id: account.id,
            balance: format_money(account.balance),
            currency: account.currency
          }
        }
      end
    end

    rescue_from Services::Errors::BaseError do |error|
      error!({ error: error.error_code, message: error.message }, error.http_status)
    end

    rescue_from Sequel::DatabaseError do |_error|
      error!({ error: 'database_error', message: 'Database operation failed' }, 500)
    end

    rescue_from :all do |_error|
      error!({ error: 'internal_error', message: 'Unexpected server error' }, 500)
    end

    get :health do
      DB.run('SELECT 1')
      { status: 'ok' }
    end

    namespace :accounts do
      route_param :account_id, type: Integer do
        params do
          requires :uuid, type: String
          requires :currency, type: String
          requires :amount, type: String
        end
        post :deposits do
          result = Services::Transactions::Deposit.call(
            account_id: params[:account_id],
            uuid: params[:uuid],
            currency: params[:currency],
            amount: params[:amount]
          )
          status(result[:created] ? 201 : 200)
          serialize_result(result)
        end

        params do
          requires :uuid, type: String
          requires :currency, type: String
          requires :amount, type: String
        end
        post :withdrawals do
          result = Services::Transactions::ReserveWithdrawal.call(
            account_id: params[:account_id],
            uuid: params[:uuid],
            currency: params[:currency],
            amount: params[:amount]
          )
          status(result[:created] ? 201 : 200)
          serialize_result(result)
        end
      end
    end

    namespace :withdrawals do
      route_param :uuid, type: String do
        post :confirm do
          serialize_result(Services::Transactions::ConfirmWithdrawal.call(uuid: params[:uuid]))
        end

        post :cancel do
          serialize_result(Services::Transactions::CancelWithdrawal.call(uuid: params[:uuid]))
        end
      end
    end

    # TODO: add authentication/authorization middleware.
  end
end
