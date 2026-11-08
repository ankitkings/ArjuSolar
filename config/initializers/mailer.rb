# This project does not load the whole Rails stack, so sending e-mail is switched on here.
#
# To send real e-mails set these (for Gmail use smtp.gmail.com, port 587 and an "App password"):
#   SMTP_ADDRESS, SMTP_PORT (default 587), SMTP_USERNAME, SMTP_PASSWORD, MAIL_FROM
# Without them the e-mails are saved as files in tmp/mails (nothing is sent).
require "action_mailer"

ActionMailer::Base.class_eval do
  prepend_view_path Rails.root.join("app/views").to_s
  self.perform_deliveries = true
  self.raise_delivery_errors = true

  if ENV["SMTP_ADDRESS"].present?
    self.delivery_method = :smtp
    self.smtp_settings = {
      address: ENV["SMTP_ADDRESS"], port: ENV.fetch("SMTP_PORT", "587").to_i,
      user_name: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"],
      authentication: :plain, enable_starttls_auto: true
    }
  else
    self.delivery_method = :file
    self.file_settings = { location: Rails.root.join("tmp/mails").to_s }
  end
end
