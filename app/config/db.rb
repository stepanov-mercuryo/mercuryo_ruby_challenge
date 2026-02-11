# frozen_string_literal: true

require 'sequel'
require 'bigdecimal'

# Connection will be established on first use
DB = Sequel.connect(
  ENV['DATABASE_URL'] || 'postgresql://mercuryo:mercuryo@localhost:5432/mercuryo_challenge',
  max_connections: 5,
  pool_timeout: 5
)

def ensure_accounts_table!
  return if DB.table_exists?(:accounts)

  DB.create_table :accounts do
    primary_key :id
    BigDecimal :balance, size: [20, 2], null: false, default: BigDecimal('0')
    String :currency, size: 10, null: false
    DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
  end
end

def ensure_transactions_table!
  return if DB.table_exists?(:transactions)

  DB.create_table :transactions do
    primary_key :id
    foreign_key :account_id, :accounts, null: false, on_delete: :restrict
    String :currency, size: 10, null: false
    BigDecimal :amount, size: [20, 2], null: false
    String :status, size: 20, null: false
    String :uuid, size: 64, null: false
    String :transaction_type, size: 20, null: false
    DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

    index :uuid, unique: true, name: :idx_transactions_uuid
    index [:account_id, :created_at], name: :idx_transactions_account_created_at
    index [:account_id, :status], name: :idx_transactions_account_status
  end
end

def ensure_indexes!
  account_indexes = DB.indexes(:accounts)
  DB.add_index(:accounts, :currency, name: :idx_accounts_currency) unless account_indexes.key?(:idx_accounts_currency)

  transaction_indexes = DB.indexes(:transactions)
  DB.add_index(:transactions, :uuid, unique: true, name: :idx_transactions_uuid) unless transaction_indexes.key?(:idx_transactions_uuid)
  unless transaction_indexes.key?(:idx_transactions_account_created_at)
    DB.add_index(:transactions, [:account_id, :created_at], name: :idx_transactions_account_created_at)
  end
  unless transaction_indexes.key?(:idx_transactions_account_status)
    DB.add_index(:transactions, [:account_id, :status], name: :idx_transactions_account_status)
  end
end

ensure_accounts_table!
ensure_transactions_table!
ensure_indexes!
