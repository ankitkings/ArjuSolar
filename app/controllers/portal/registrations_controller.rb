module Portal
  # A client registers with an e-mail address and gets a link to set the password
  class RegistrationsController < ApplicationController
    include PortalMailing

    def new
      @customer = Customer.new
    end

    def create
      return render(:sent) if params[:website].present?   # hidden field only bots fill

      attrs = params.require(:customer).permit(:name, :email, :phone)
      @customer = Customer.find_or_initialize_by(email: attrs[:email].to_s.strip.downcase)

      if @customer.persisted? && @customer.password_set?
        @customer.errors.add(:email, "is already registered. Please log in, or choose “Forgot password”.")
        return render(:new, status: :unprocessable_entity)
      end
      if recently_sent?(@customer)
        @customer.errors.add(:base, "We have just e-mailed you a link. Please check your inbox (and spam folder), or try again in a minute.")
        return render(:new, status: :unprocessable_entity)
      end

      @customer.assign_attributes(name: attrs[:name], phone: attrs[:phone])
      return render(:new, status: :unprocessable_entity) unless @customer.save

      @link = send_password_mail(@customer, :setup)
      if @link
        @hint = development_hint(@link)
        render :sent
      else
        @customer.errors.add(:base, "We could not send the e-mail right now. Please try again in a little while, or phone us on +91 7049465926.")
        render :new, status: :service_unavailable
      end
    end
  end
end
