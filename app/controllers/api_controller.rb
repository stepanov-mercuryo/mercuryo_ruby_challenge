# frozen_string_literal: true

require 'grape'
require_relative '../config/db'

module Controllers
  class ApiController < Grape::API
    format :json

    get :health do
      # Check database connection
      DB.run('SELECT 1')
      { status: 'ok' }
    rescue Sequel::DatabaseConnectionError, Sequel::DatabaseError => e
      error!({ status: 'error', message: 'Database connection failed' }, 503)
    end
  end
end
