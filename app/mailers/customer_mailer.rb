# The e-mails a client receives: the link to set the password, and the link to reset it
class CustomerMailer < ApplicationMailer

  def set_password(customer, link)
    @customer = customer
    @link = link
    mail to: customer.email, subject: "Set your Arju Solars password"
  end

  def reset_password(customer, link)
    @customer = customer
    @link = link
    mail to: customer.email, subject: "Reset your Arju Solars password"
  end
end
