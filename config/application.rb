require File.expand_path('../boot', __FILE__)

require 'csv'
require 'rails/all'

ENV['WEB'] = '1' if Rails.env.test? || (ENV['RAILS_GROUPS'] == 'assets')
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)
Bundler.require(:web) if ENV['WEB']

module App
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.autoload_paths += %W(#{config.root}/app/controllers/concerns)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer
    config.active_record.observers = :notification_sweeper

    config.serve_static_files = true

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.time_zone = 'Pacific Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :password_confirmation, :auth_token]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    #config.active_record.schema_format = :sql
    config.active_record.schema_format = :ruby

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    # config.active_record.whitelist_attributes = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.active_record.raise_in_transactional_callbacks = true

    config.before_configuration do
      env_file = File.join(Rails.root, 'config', 'local_env.yml')
      YAML.load(File.open(env_file)).each do |key, value|
        ENV[key.to_s] = value
      end if File.exist?(env_file)
    end

    config.assets.initialize_on_precompile = false

    config.assets.precompile += %w(
      pdf.css plugins.css
      admin/active_admin.css admin/active_admin.js
      jquery.placesAutocomplete.js
      reports.css jquery.reportBuilder.js jquery.reportTableScroller.js
      form_builder.css jquery.formBuilder.js pdf.js
    )

    config.assets.paths << Rails.root.join('app', 'assets', 'stylesheets', 'font')

    config.cache_store = :dalli_store

    I18n.enforce_available_locales = true

    config.middleware.insert_before 'ActionDispatch::Static', 'Rack::Cors' do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :head, :delete, :options]
      end
    end

    config.eager_load_paths += ["#{Rails.root}/lib"]

    # We dont need active_admin to be in eager_loaded in workers
    unless ENV['WEB']
      config.eager_load_paths.reject! { |a| a.include?('app/admin') || a.include?('app/inputs') }
      # require Rails.root.join 'app/controllers/application_controller' #need for devise initializator
    end

    GC::Profiler.enable
  end
end

class ActiveRecordOverrideRailtie < Rails::Railtie
  initializer 'active_record.initialize_database.override' do |app|

    ActiveSupport.on_load(:active_record) do
      if (url = ENV['DATABASE_URL'])
        ActiveRecord::Base.connection_pool.disconnect!
        parsed_url = URI.parse(url)
        config =  {
          adapter:             'postgis',
          host:                parsed_url.host,
          encoding:            'unicode',
          database:            parsed_url.path.split("/")[-1],
          port:                parsed_url.port,
          username:            parsed_url.user,
          password:            parsed_url.password
        }
        establish_connection(config)
      end
    end
  end
end
