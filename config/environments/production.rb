require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.assume_ssl = config.force_ssl
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
  config.cache_store = :memory_store
  config.active_storage.service = :local   # uploads live in storage/ - keep that folder on a persistent disk
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  # SECRET_KEY_BASE must be set as an environment variable in production
end
