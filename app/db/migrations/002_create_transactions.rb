# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:transactions) do
      primary_key :id
      foreign_key :account_id, :accounts, null: false, on_delete: :restrict
      String :currency, size: 3, null: false
      BigDecimal :amount, size: [20, 2], null: false
      String :status, size: 16, null: false
      String :uuid, size: 128, null: false
      String :transaction_type, size: 16, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      check(Sequel.lit("status IN ('pending', 'completed', 'cancelled')"))
      check(Sequel.lit("transaction_type IN ('deposit', 'withdrawal')"))
      check(Sequel.lit("currency ~ '^[A-Z]{3}$'"))
      check(
        Sequel.lit(
          "(transaction_type = 'deposit' AND status = 'completed' AND amount > 0) OR " \
          "(transaction_type = 'withdrawal' AND amount < 0)"
        )
      )

      index :uuid, unique: true
      index %i[account_id created_at]
      index %i[status created_at]
    end
  end
end
