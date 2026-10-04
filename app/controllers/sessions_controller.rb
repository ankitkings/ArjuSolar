class SessionsController < ApplicationController
  MAX_ATTEMPTS = 10

  def new
    redirect_to admin_root_path if current_admin
  end

  def create
    key = "login_attempts:#{request.remote_ip}"
    if Rails.cache.read(key).to_i >= MAX_ATTEMPTS
      flash.now[:alert] = "Too many attempts. Try again in 10 minutes."
      return render :new, status: :too_many_requests
    end

    admin = AdminUser.find_by(email: params[:email].to_s.strip.downcase)
    if admin&.authenticate(params[:password])
      Rails.cache.delete(key)
      reset_session
      session[:admin_id] = admin.id
      redirect_to admin_root_path
    else
      Rails.cache.write(key, Rails.cache.read(key).to_i + 1, expires_in: 10.minutes)
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unauthorized
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Logged out"
  end
end