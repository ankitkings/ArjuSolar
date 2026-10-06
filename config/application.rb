require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module ArjuSolars
  class Application < Rails::Application
    config.load_defaults 7.1
    config.time_zone = "Kolkata"
    config.generators.system_tests = nil
  end
end
