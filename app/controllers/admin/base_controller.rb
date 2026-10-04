module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin

    private

    def require_admin
      redirect_to admin_login_path, alert: "Please log in" unless current_admin
    end
  end
end
