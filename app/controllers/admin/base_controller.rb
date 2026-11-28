module Admin
  class BaseController < ApplicationController
    include LoginGuard
    layout "admin"

    # the money pages open only after the owner's own password (see OwnerLock)
    OWNER_PAGES = %w[payroll salary_payments payment_settings margins earnings wallet expenses].freeze

    before_action :require_admin
    before_action :require_owner_unlock, if: -> { OWNER_PAGES.include?(controller_name) }
    before_action :mark_module_seen

    private

    def require_admin
      deny_access(admin_login_path) unless current_admin
    end

    def owner_unlocked?
      session[:owner_unlocked_at].to_i > OwnerLock::IDLE_MINUTES.minutes.ago.to_i
    end

    def require_owner_unlock
      if owner_unlocked?
        session[:owner_unlocked_at] = Time.current.to_i      # every use keeps it open for another 15 minutes
      elsif background_request?
        head :unauthorized
      else
        redirect_to admin_owner_unlock_path(return_to: (request.get? ? request.fullpath : admin_root_path))
      end
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
