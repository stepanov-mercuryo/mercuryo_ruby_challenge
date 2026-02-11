# frozen_string_literal: true

require 'sequel'

# Connection will be established on first use
DB = Sequel.connect(
  ENV['DATABASE_URL'] || 'postgresql://mercuryo:mercuryo@localhost:5432/mercuryo_challenge',
  max_connections: 5,
  pool_timeout: 5
)
