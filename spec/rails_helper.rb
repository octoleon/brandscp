# encoding: utf-8
# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require 'simplecov'

if ENV["COVERAGE"]
  SimpleCov.start 'rails' do
    add_filter 'lib/legacy'
  end
end

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'shoulda/matchers'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'database_cleaner'
require 'capybara-screenshot'
require 'capybara-screenshot/rspec'
require 'sms-spec'
require 'factory_girl'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  config.infer_spec_type_from_file_location!

  config.render_views

  config.filter_run show_in_doc: true if ENV['APIPIE_RECORD']

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # config.include Capybara::DSL, :type => :request
  config.include SignHelper, type: :feature
  config.include RequestsHelper, type: :feature

  config.before(:suite) do
    ActiveRecord::Base.connection.execute(IO.read('db/functions.sql'))
    ActiveRecord::Base.connection.execute(IO.read('db/views.sql'))
  end

  config.before(:each) do |example|
    reset_email

    # make sure we star each test in a clean state
    User.current = nil
    Company.current = nil
    Time.zone = Rails.application.config.time_zone

    Rails.logger.debug "\n\n\n\n\n\n\n\n\n\n"
    Rails.logger.debug '*' * 80
    Rails.logger.debug "***** EXAMPLE: #{example.full_description}"
    Rails.logger.debug '*' * 80
  end

  config.after(:each, js: true) do
    wait_for_ajax
    page.execute_script('window.localStorage.clear()')
  end

  config.include(SmsSpec::Helpers)
  config.include(SmsSpec::Matchers)
  config.include(BrandscopiSpecHelpers)

  SmsSpec.driver = :"twilio-ruby" # this can be any available sms-spec driver
end
