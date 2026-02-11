# frozen_string_literal: true

require 'minitest/autorun'
require 'securerandom'

ENV['RACK_ENV'] = 'test'

require_relative '../boot'

Sequel.const_set(:BasicObject, ::BasicObject) unless Sequel.const_defined?(:BasicObject)
require 'sequel/extensions/migration'

Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))

class Minitest::Test
  def setup
    DB[:transactions].delete
    DB[:accounts].delete
  end
end
