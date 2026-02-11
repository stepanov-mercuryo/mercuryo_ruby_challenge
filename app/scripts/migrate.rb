# frozen_string_literal: true

require_relative '../config/db'

Sequel.const_set(:BasicObject, ::BasicObject) unless Sequel.const_defined?(:BasicObject)
require 'sequel/extensions/migration'

Sequel.extension :migration

migrations_path = File.expand_path('../db/migrations', __dir__)
Sequel::Migrator.run(DB, migrations_path)

puts 'Migrations applied successfully'
