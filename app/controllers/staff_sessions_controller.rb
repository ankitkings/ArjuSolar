class StaffSessionsController < ApplicationController
  MAX_ATTEMPTS = 10

  def new
    redirect_to staff_root_path if current_staff
  end

  def create
    key = "staff_login_attempts:#{request.remote_ip}"
    if Rails.cache.read(key).to_i >= MAX_ATTEMPTS
      flash.now[:alert] = "Too many attempts. Try again in 10 minutes."
      return render :new, status: :too_many_requests
    end

    member = TeamMember.find_by(email: params[:email].to_s.strip.downcase)
    if member&.can_login? && member.authenticate(params[:password])
      Rails.cache.delete(key)
      admin_id = session[:admin_id]          # keep admin login if the same browser is used
      reset_session
      session[:admin_id] = admin_id if admin_id
      session[:staff_id] = member.id
      redirect_to staff_root_path
    else
      Rails.cache.write(key, Rails.cache.read(key).to_i + 1, expires_in: 10.minutes)
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unauthorized
    end
  end

  def destroy
    session.delete(:staff_id)
    redirect_to root_path, notice: "Logged out"
  end
end
