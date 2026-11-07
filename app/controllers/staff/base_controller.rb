module Staff
  class BaseController < ApplicationController
    include LoginGuard
    layout "staff"
    before_action :require_staff

    private

    def require_staff
      deny_access(staff_login_path) unless current_staff
    end
  end
end
