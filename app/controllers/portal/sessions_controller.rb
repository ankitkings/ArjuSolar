module Portal
  # Login with the registered e-mail address and the password
  class SessionsController < ApplicationController
    def new
      redirect_to portal_root_path if session[:customer_id] && Customer.exists?(session[:customer_id])
    end

    def create
      customer = Customer.find_by(email: params[:email].to_s.strip.downcase)

      if customer&.locked?
        flash.now[:alert] = "Too many wrong attempts. Please try again after #{Customer::LOCK_MINUTES} minutes, or reset your password."
        render :new, status: :too_many_requests
      elsif customer&.password_set? && customer.authenticate(params[:password].to_s)
        customer.sign_in!
        others = session.to_h.slice("admin_id", "staff_id")      # keep an admin / staff login of the same browser
        reset_session
        others.each { |key, value| session[key] = value }
        session[:customer_id] = customer.id
        redirect_to portal_root_path, notice: "Welcome back, #{customer.first_name}!"
      else
        customer&.register_failure!
        flash.now[:alert] = "The e-mail or password is not correct. If you have not set a password yet, use the link we e-mailed you, or register again to get a new one."
        render :new, status: :unauthorized
      end
    end

    def destroy
      session.delete(:customer_id)
      redirect_to root_path, notice: "You are logged out."
    end
  end
end
