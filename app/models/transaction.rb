# frozen_string_literal: true

class Transaction < Sequel::Model(:transactions)
  plugin :timestamps, update_on_create: true

  many_to_one :account
end
