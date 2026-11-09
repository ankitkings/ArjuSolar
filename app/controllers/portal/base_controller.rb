module Portal
  # Everything inside the client portal needs a logged-in client
  class BaseController < ApplicationController
    include LoginGuard
    before_action :require_customer
    helper_method :current_customer

    private

    def current_customer
      @current_customer ||= Customer.find_by(id: session[:customer_id])
    end

    def require_customer
      deny_access(portal_login_path, message: "Please log in with your registered e-mail to continue.") unless current_customer
    end
  end
end
