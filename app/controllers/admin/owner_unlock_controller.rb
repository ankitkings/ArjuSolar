module Admin
  # The owner's password: it opens the money pages (earnings, wallet, payroll, salary records, payment setup, margins)
  class OwnerUnlockController < BaseController
    def new
      @lock = OwnerLock.current
      @return_to = safe_return(params[:return_to])
    end

    def create
      @lock = OwnerLock.current
      @return_to = safe_return(params[:return_to])

      if @lock.nil?                                   # the first time: the owner makes the password
        fresh = OwnerLock.new(password: params[:password].to_s, password_confirmation: params[:password_confirmation].to_s)
        return open_and_go(@return_to) if fresh.save
        @error = fresh.errors.full_messages.to_sentence
      elsif @lock.locked?
        @error = "Too many wrong attempts. Try again after #{OwnerLock::LOCK_MINUTES} minutes."
      elsif @lock.authenticate(params[:password].to_s)
        @lock.clear_failures!
        return open_and_go(@return_to)
      else
        @lock.register_failure!
        @error = "That is not the owner password."
      end
      render :new, status: :unprocessable_entity
    end

    def destroy
      session.delete(:owner_unlocked_at)
      redirect_to admin_root_path, notice: "The money pages are locked."
    end

    def password
      return redirect_to(admin_owner_unlock_path(return_to: admin_owner_password_path)) unless owner_unlocked?
    end

    def update_password
      return redirect_to(admin_owner_unlock_path(return_to: admin_owner_password_path)) unless owner_unlocked?
      lock = OwnerLock.current
      if lock.nil? || !lock.authenticate(params[:current_password].to_s)
        redirect_to admin_owner_password_path, alert: "The current owner password is not correct."
      elsif lock.update(password: params[:password].to_s, password_confirmation: params[:password_confirmation].to_s)
        redirect_to admin_earnings_path, notice: "The owner password was changed."
      else
        redirect_to admin_owner_password_path, alert: lock.errors.full_messages.to_sentence
      end
    end

    private

    def open_and_go(path)
      session[:owner_unlocked_at] = Time.current.to_i
      redirect_to path
    end

    # only pages of the admin panel; never another website
    def safe_return(path)
      path = path.to_s
      path.start_with?("/admin/") && !path.start_with?("//") ? path : admin_earnings_path
    end
  end
end
