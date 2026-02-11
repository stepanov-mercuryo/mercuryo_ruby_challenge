# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:accounts) do
      primary_key :id
      BigDecimal :balance, size: [20, 2], null: false, default: 0
      String :currency, size: 3, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      check(Sequel.lit('balance >= 0'))
      check(Sequel.lit("currency ~ '^[A-Z]{3}$'"))
    end
  end
end
