require 'rubygems'
require 'spork'
#uncomment the following line to use spork with the debugger
#require 'spork/ext/ruby-debug'


Spork.prefork do
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'capybara/rspec'
  require "selenium-webdriver"
  require 'email_spec'
  require 'rspec/autorun'

  RSpec.configure do |config|
      config.include(EmailSpec::Helpers)
      config.include(EmailSpec::Matchers)
      # config.fixture_path = "#{::Rails.root}/spec/fixtures"
      # config.use_transactional_fixtures = true
      # config.infer_base_class_for_anonymous_controllers = true
      config.mock_with :rspec
    
      Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
    
      # Clean up the database
      require 'database_cleaner'
      config.before(:suite) do
        DatabaseCleaner.strategy = :truncation
        DatabaseCleaner.orm = "mongoid"
      end
    
      config.before(:each) do
        DatabaseCleaner.clean
      end
    
  end
end

Spork.each_run do
  Dir.glob("#{Rails.root}/app/models/*.rb").sort.each { |file| load file }
end

