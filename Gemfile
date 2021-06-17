source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '2.2.3'

gem 'rails', '4.2.4'
gem 'rails-observers'
gem 'activerecord-session_store'
gem 'rack-timeout'

# Bundle edge Rails instead:
# gem 'rails', git: 'git://github.com/rails/rails.git'

gem 'pg'
gem 'devise'
gem 'devise_invitable'
gem 'cancancan', '~> 1.9'
gem 'slim-rails'
gem 'inherited_resources'
gem 'has_scope'
gem 'clerk'
gem 'rabl'
gem 'oj'
gem 'simple-navigation'
gem 'aasm'
gem 'countries'
gem 'company_scoped', path: 'vendor/gems/company_scoped'
gem 'legacy', path: 'vendor/gems/legacy', require: false
gem 'newrelic_rpm'
gem 'paperclip', '~> 4.3'
gem 'aws-sdk'
gem 'google_places'
gem 'timeliness'
gem 'american_date'
gem 'sunspot_rails', github: 'sunspot/sunspot'
gem 'sunspot_stats'
gem 'progress_bar', require: false
gem 'geocoder'
gem 'rubyzip'
gem 'redis'
gem 'sinatra', require: false
gem 'sidekiq'
gem 'sidekiq-limit_fetch'
gem 'unread'
gem 'nearest_time_zone'
gem 'memcachier'
gem 'dalli'
gem 'apipie-rails'
gem 'twilio-ruby'
gem 'nested_form'
gem 'wicked_pdf'
gem 'rack-cors', require: 'rack/cors'
gem 'roo'
gem 'similar_text'
gem 'activerecord-postgis-adapter'
gem 'clockwork', require: false
gem 'pgbackups-archive'
gem 'active_model_serializers'
gem 'rgeo-geojson'
gem 'paper_trail', '~> 4.0.0'
gem 'simple_form', '~> 3.2.0'
gem 'country_select', '2.0.0.rc1'
gem 'paperclip-av-transcoder'

# For memory debugging
# gem "allocation_stats"

group :development do
  gem 'rack-livereload'
  gem 'guard-livereload', require: false
  gem 'annotate', '>=2.5.0'
  gem 'quiet_assets', '>= 1.0.1'
  gem 'oink'
  gem 'pry-rails'
  gem 'haml'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'bullet'
  gem 'nkss-rails', github: 'nadarei/nkss-rails'
end

# Gems that are only required for the web process, to prevent
# workers loading not needed libraries
group :web do
  gem 'activeadmin', github: 'activeadmin/active_admin'
  gem 'font_assets', path: 'vendor/gems/font_assets'
  gem 'puma'
end

# Gems used only for assets and not required
# in production environments by default.
gem 'bootstrap-sass', '~> 2.3.2'
gem 'sass-rails', '~> 4.0.3'
gem 'coffee-rails'
gem 'uglifier', '>= 1.3.0'

gem 'jquery-rails'

group :test, :development do
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'factory_girl_rails', require: false
  gem 'rspec-rails', '~> 3.3.3'
  gem 'populator'
  gem 'sunspot_solr', github: 'sunspot/sunspot'
  gem 'timecop'
  gem 'faker'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'parallel_tests'
  gem 'rspec-retry'
end

group :test do
  gem 'capybara'
  gem 'rspec-mocks'
  # gem "capybara-webkit"
  gem 'poltergeist'
  # gem 'selenium-webdriver'
  gem 'email_spec', '>= 1.4.0'
  gem 'shoulda-matchers', require: false
  gem 'sunspot_matchers'
  # gem 'launchy'
  gem 'sunspot_test'
  # gem 'sunspot-rails-tester'
  gem 'simplecov', require: false
  gem 'capybara-screenshot'
  gem 'fuubar', '2.0.0'
  gem 'database_cleaner'
  # gem 'sms-spec', '~> 0.1.9'
  gem 'sms-spec'
  gem 'pdf-reader'
  # gem 'vcr'
  # gem 'webmock'
end

group :production do
  gem 'airbrake'
  gem 'rails_12factor'
end

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'debugger'
