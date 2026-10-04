module Staff
  class BaseController < ApplicationController
    layout "staff"
    before_action :require_staff

    private

    def require_staff
      redirect_to staff_login_path, alert: "Please log in" unless current_staff
    end
  end
end
