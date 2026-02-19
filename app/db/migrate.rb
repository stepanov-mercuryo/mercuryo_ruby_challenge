# frozen_string_literal: true

require 'sequel'
require_relative '../config/db'

Sequel.extension :migration

migrations_path = File.expand_path('migrations', __dir__)
Sequel::Migrator.run(DB, migrations_path)

puts "Migrations applied from #{migrations_path}"
