# frozen_string_literal: true

require 'bigdecimal'
require_relative 'test_helper'

class TransactionsFlowTest < Minitest::Test
  def test_deposit_happy_path
    account = create_account(balance: '10.00')

    result = Services::Transactions::Deposit.call(
      account_id: account.id,
      uuid: SecureRandom.uuid,
      currency: 'USD',
      amount: '12.50'
    )

    assert_equal true, result[:created]
    assert_equal BigDecimal('22.50'), Account[account.id].balance
    assert_equal 'deposit', result[:transaction].transaction_type
    assert_equal 'completed', result[:transaction].status
  end

  def test_deposit_idempotency_same_payload
    account = create_account(balance: '10.00')
    uuid = SecureRandom.uuid

    first = Services::Transactions::Deposit.call(
      account_id: account.id,
      uuid: uuid,
      currency: 'USD',
      amount: '12.00'
    )
    second = Services::Transactions::Deposit.call(
      account_id: account.id,
      uuid: uuid,
      currency: 'USD',
      amount: '12.00'
    )

    assert_equal true, first[:created]
    assert_equal false, second[:created]
    assert_equal 1, Transaction.where(uuid: uuid).count
    assert_equal BigDecimal('22.00'), Account[account.id].balance
  end

  def test_deposit_idempotency_conflict_for_different_payload
    account = create_account(balance: '10.00')
    uuid = SecureRandom.uuid

    Services::Transactions::Deposit.call(
      account_id: account.id,
      uuid: uuid,
      currency: 'USD',
      amount: '12.00'
    )

    error = assert_raises(Services::Errors::ConflictError) do
      Services::Transactions::Deposit.call(
        account_id: account.id,
        uuid: uuid,
        currency: 'USD',
        amount: '11.00'
      )
    end

    assert_match('uuid is already used', error.message)
  end

  def test_withdrawal_reserve_confirm_happy_path
    account = create_account(balance: '100.00')
    uuid = SecureRandom.uuid

    reserve = Services::Transactions::ReserveWithdrawal.call(
      account_id: account.id,
      uuid: uuid,
      currency: 'USD',
      amount: '40.00'
    )

    assert_equal true, reserve[:created]
    assert_equal 'pending', reserve[:transaction].status
    assert_equal BigDecimal('60.00'), Account[account.id].balance

    confirm = Services::Transactions::ConfirmWithdrawal.call(uuid: uuid)
    assert_equal 'completed', confirm[:transaction].status
    assert_equal BigDecimal('60.00'), Account[account.id].balance
  end

  def test_withdrawal_cancel_returns_reserved_funds
    account = create_account(balance: '100.00')
    uuid = SecureRandom.uuid

    Services::Transactions::ReserveWithdrawal.call(
      account_id: account.id,
      uuid: uuid,
      currency: 'USD',
      amount: '30.00'
    )
    cancel = Services::Transactions::CancelWithdrawal.call(uuid: uuid)

    assert_equal 'cancelled', cancel[:transaction].status
    assert_equal BigDecimal('100.00'), Account[account.id].balance
  end

  def test_double_confirm_fails_with_conflict
    account = create_account(balance: '100.00')
    uuid = SecureRandom.uuid

    Services::Transactions::ReserveWithdrawal.call(
      account_id: account.id,
      uuid: uuid,
      currency: 'USD',
      amount: '20.00'
    )
    Services::Transactions::ConfirmWithdrawal.call(uuid: uuid)

    assert_raises(Services::Errors::ConflictError) do
      Services::Transactions::ConfirmWithdrawal.call(uuid: uuid)
    end
  end

  def test_withdrawal_insufficient_funds
    account = create_account(balance: '10.00')

    assert_raises(Services::Errors::InsufficientFundsError) do
      Services::Transactions::ReserveWithdrawal.call(
        account_id: account.id,
        uuid: SecureRandom.uuid,
        currency: 'USD',
        amount: '11.00'
      )
    end
  end

  def test_concurrent_withdrawals_allow_only_one_success_when_funds_not_enough_for_both
    account = create_account(balance: '100.00')
    outcomes = Queue.new

    threads = 2.times.map do
      Thread.new do
        begin
          result = Services::Transactions::ReserveWithdrawal.call(
            account_id: account.id,
            uuid: SecureRandom.uuid,
            currency: 'USD',
            amount: '80.00'
          )
          outcomes << [:ok, result]
        rescue StandardError => error
          outcomes << [:error, error]
        end
      end
    end
    threads.each(&:join)

    results = 2.times.map { outcomes.pop }
    successful = results.select { |status, _| status == :ok }
    failed = results.select { |status, _| status == :error }

    assert_equal 1, successful.size
    assert_equal 1, failed.size
    assert_instance_of Services::Errors::InsufficientFundsError, failed.first.last
    assert_equal BigDecimal('20.00'), Account[account.id].balance
    assert_equal 1, Transaction.where(transaction_type: 'withdrawal').count
  end

  private

  def create_account(balance:, currency: 'USD')
    Account.create(balance: BigDecimal(balance), currency: currency)
  end
end
