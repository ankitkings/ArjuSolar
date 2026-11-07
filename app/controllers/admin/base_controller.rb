module Admin
  class BaseController < ApplicationController
    include LoginGuard
    layout "admin"
    before_action :require_admin

    private

    def require_admin
      deny_access(admin_login_path) unless current_admin
    end
  end
end
