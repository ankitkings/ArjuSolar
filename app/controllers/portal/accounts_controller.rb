module Portal
  # The client's own details and password
  class AccountsController < BaseController
    def show; end

    def update
      if current_customer.update(params.require(:customer).permit(:name, :phone))
        redirect_to portal_account_path, notice: "Your details are saved."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def change_password
      new_password = params[:new_password].to_s
      if !current_customer.authenticate(params[:current_password].to_s)
        @password_error = "The current password is not correct."
      elsif new_password.length < 8 || new_password.length > 72
        @password_error = "The new password must have 8 to 72 characters."
      elsif new_password != params[:new_password_confirmation].to_s
        @password_error = "The two new passwords are not the same."
      else
        current_customer.password = new_password
        current_customer.password_confirmation = new_password
        if current_customer.save
          current_customer.update_columns(password_set_at: Time.current)
          return redirect_to portal_account_path, notice: "Your password was changed."
        end
        @password_error = current_customer.errors.full_messages.to_sentence
      end
      render :show, status: :unprocessable_entity
    end
  end
end
