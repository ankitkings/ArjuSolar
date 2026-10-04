class ApplicationController < ActionController::Base
  helper_method :current_admin, :current_staff

  private

  def current_admin
    @current_admin ||= AdminUser.find_by(id: session[:admin_id])
  end

  def current_staff
    @current_staff ||= TeamMember.find_by(id: session[:staff_id], active: true)
  end
end
