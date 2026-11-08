module Portal
  # Forgotten password, and the page behind the e-mailed link where the password is chosen
  class PasswordsController < ApplicationController
    include PortalMailing
    before_action :load_customer, only: %i[edit update]

    def forgot; end

    def send_reset
      customer = Customer.find_by(email: params[:email].to_s.strip.downcase)
      link = customer && !recently_sent?(customer) ? send_password_mail(customer, customer.password_set? ? :reset : :setup) : nil
      redirect_to portal_login_path, notice: "If that e-mail is registered, we have sent a link to choose a new password. It can take a minute to arrive.#{development_hint(link)}"
    end

    def edit; end

    def update
      password = params[:password].to_s
      if password.length < 8
        @error = "The password must have at least 8 characters."
      elsif password.length > 72
        @error = "The password is too long (72 characters at most)."
      elsif password != params[:password_confirmation].to_s
        @error = "The two passwords are not the same."
      else
        @customer.password = password
        @customer.password_confirmation = params[:password_confirmation].to_s
        if @customer.save
          @customer.update_columns(password_set_at: Time.current, failed_attempts: 0, locked_until: nil)
          @customer.link_existing_requests!
          return redirect_to portal_login_path, notice: "Your password is saved. Please log in with your e-mail and the new password."
        end
        @error = @customer.errors.full_messages.to_sentence
      end
      render :edit, status: :unprocessable_entity
    end

    private

    def load_customer
      @customer = Customer.find_by_link_token(params[:token])
      render :invalid, status: :gone unless @customer
    end
  end
end
