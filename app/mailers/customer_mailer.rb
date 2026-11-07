# The e-mails a client receives: the link to set the password, and the link to reset it
class CustomerMailer < ActionMailer::Base
  default from: -> { ENV["MAIL_FROM"].presence || "#{SiteSetting.current.company_name} <no-reply@arjusolars.in>" }
  layout false

  def set_password(customer, link)
    @customer = customer
    @link = link
    @company = SiteSetting.current.company_name
    mail to: customer.email, subject: "Set your #{@company} password"
  end

  def reset_password(customer, link)
    @customer = customer
    @link = link
    @company = SiteSetting.current.company_name
    mail to: customer.email, subject: "Reset your #{@company} password"
  end
end
