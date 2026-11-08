# Sends the "set your password" / "reset your password" e-mails
module PortalMailing
  extend ActiveSupport::Concern

  private

  # kind: :setup (first password) or :reset (forgotten password). Returns the link, or nil if the e-mail could not be sent.
  def send_password_mail(customer, kind)
    token = customer.generate_token_for(kind == :reset ? :password_reset : :password)
    path = portal_set_password_path(token)
    base = ENV["PUBLIC_BASE_URL"].to_s.chomp("/")
    link = base.present? ? "#{base}#{path}" : "#{request.base_url}#{path}"
    mail = kind == :reset ? CustomerMailer.reset_password(customer, link) : CustomerMailer.set_password(customer, link)
    mail.deliver_now
    customer.update_columns(setup_sent_at: Time.current)
    link
  rescue StandardError => e
    Rails.logger.error("Client e-mail failed (#{customer.email}): #{e.class}: #{e.message}")
    nil
  end

  # while developing nothing is really sent, so the link is shown on the screen
  def development_hint(link)
    Rails.env.development? && link ? " (Development: no e-mail is sent. Use this link: #{link})" : ""
  end

  def recently_sent?(customer)
    customer.setup_sent_at.present? && customer.setup_sent_at > 1.minute.ago
  end
end
