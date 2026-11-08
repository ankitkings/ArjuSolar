# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true
  # config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.force_ssl = false # temporarily (if you're accessing via HTTP + IP)
  config.assume_ssl = config.force_ssl
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
  config.cache_store = :memory_store
  config.active_storage.service = :local # uploads live in storage/ - keep that folder on a persistent disk
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  # SECRET_KEY_BASE must be set as an environment variable in production

  config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: ENV.fetch("MAILER_HOST"),
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.action_mailer.default_options = {
    from: ENV.fetch("MAILER_SENDER")
  }

  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST"),
    protocol: "https"
  }
end
