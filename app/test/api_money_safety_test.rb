# frozen_string_literal: true

require 'json'
require 'bigdecimal'
require 'rack/mock'
require_relative 'test_helper'
require_relative '../controllers/api_controller'

class ApiMoneySafetyTest < Minitest::Test
  def test_serializes_large_balance_without_precision_loss
    account = create_account(balance: '1234567890123456.78')

    response = post_json(
      "/api/v1/accounts/#{account.id}/deposits",
      {
        uuid: SecureRandom.uuid,
        currency: 'USD',
        amount: '0.01'
      }
    )
    body = JSON.parse(response.body)

    assert_equal 201, response.status
    assert_equal '1234567890123456.79', body.dig('account', 'balance')
    assert_equal '0.01', body.dig('transaction', 'amount')
  end

  def test_returns_422_when_amount_exceeds_numeric_limit
    account = create_account(balance: '0.00')

    response = post_json(
      "/api/v1/accounts/#{account.id}/deposits",
      {
        uuid: SecureRandom.uuid,
        currency: 'USD',
        amount: '1000000000000000000.00'
      }
    )
    body = JSON.parse(response.body)

    assert_equal 422, response.status
    assert_equal 'validation_error', body['error']
  end

  def test_returns_422_when_resulting_balance_exceeds_numeric_limit
    account = create_account(balance: '999999999999999999.99')

    response = post_json(
      "/api/v1/accounts/#{account.id}/deposits",
      {
        uuid: SecureRandom.uuid,
        currency: 'USD',
        amount: '0.01'
      }
    )
    body = JSON.parse(response.body)

    assert_equal 422, response.status
    assert_equal 'validation_error', body['error']
  end

  private

  def post_json(path, payload)
    Rack::MockRequest.new(Controllers::ApiController).post(
      path,
      'CONTENT_TYPE' => 'application/json',
      input: JSON.dump(payload)
    )
  end

  def create_account(balance:, currency: 'USD')
    Account.create(balance: BigDecimal(balance), currency: currency)
  end
end
