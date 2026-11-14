module Admin
  class BaseController < ApplicationController
    include LoginGuard
    layout "admin"
    before_action :require_admin
    before_action :mark_module_seen

    private

    def require_admin
      deny_access(admin_login_path) unless current_admin
    end

    # opening the list page of a module (Users, Maintenance ...) clears its "N new" in the menu
    def mark_module_seen
      return unless current_admin && request.get? && !background_request?
      key = ModuleSeen::CONTROLLERS[controller_name]
      return unless key
      return unless action_name == "index"
      ModuleSeen.mark_seen!(current_admin, key)
    end
  end
end
