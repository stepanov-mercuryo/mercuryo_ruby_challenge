# frozen_string_literal: true

class Account < Sequel::Model(:accounts)
  plugin :timestamps, update_on_create: true

  one_to_many :transactions
end
