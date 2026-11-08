module Admin
  # Admin > Clients: the admin creates the client profiles. A client then gets an e-mail to set a password.
  # Requests (from the contact form or the portal) join a client by the same e-mail or phone number.
  class CustomersController < BaseController
    include PortalMailing

    def index
      @customer = Customer.new(name: params[:name], email: params[:email], phone: params[:phone])
      load_index
    end

    def create
      @customer = Customer.new(params.require(:customer).permit(:name, :email, :phone))
      if @customer.save
        linked = @customer.link_existing_requests!
        message = "Client profile created for #{@customer.name}."
        message += " #{linked} earlier #{'request'.pluralize(linked)} matched by e-mail or phone and #{linked == 1 ? 'was' : 'were'} linked." if linked.positive?
        if params[:send_link] == "1"
          link = send_password_mail(@customer, :setup)
          message += link ? " The e-mail with the link to set a password was sent to #{@customer.email}.#{development_hint(link)}" : " The e-mail could not be sent – use “E-mail set-password link” again later."
        end
        redirect_to admin_customers_path, notice: message
      else
        load_index
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      @customer = Customer.find(params[:id])
    end

    def update
      @customer = Customer.find(params[:id])
      if @customer.update(params.require(:customer).permit(:name, :email, :phone))
        linked = @customer.link_existing_requests!
        redirect_to admin_customers_path, notice: "Saved.#{" #{linked} more #{'request'.pluralize(linked)} linked." if linked.positive?}"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # the requests stay; they just have no client profile any more
    def destroy
      customer = Customer.find(params[:id])
      customer.destroy
      redirect_to admin_customers_path, notice: "The profile of #{customer.name} was removed. Their requests are still in the system."
    end

    def settings
      setting = PortalSetting.current
      if setting.update(params.require(:portal_setting).permit(:warranty_months))
        redirect_to admin_customers_path, notice: "The warranty period is now #{setting.warranty_months} months."
      else
        redirect_to admin_customers_path, alert: setting.errors.full_messages.to_sentence
      end
    end

    # sends the set-password (or reset) link again
    def resend
      customer = Customer.find(params[:id])
      link = send_password_mail(customer, customer.password_set? ? :reset : :setup)
      if link
        redirect_to admin_customers_path, notice: "The link was e-mailed to #{customer.email}.#{development_hint(link)}"
      else
        redirect_to admin_customers_path, alert: "The e-mail could not be sent. Check the e-mail settings (SMTP)."
      end
    end

    private

    def load_index
      scope = Customer.order(created_at: :desc)
      if params[:q].present?
        q = "%#{Customer.sanitize_sql_like(params[:q].to_s.strip)}%"
        scope = scope.where("name LIKE :q OR email LIKE :q OR phone LIKE :q", q: q)
      end
      @customers = scope.to_a
      @request_counts = ServiceRequest.where(customer_id: @customers.map(&:id)).group(:customer_id).count
      @unlinked = ServiceRequest.where(customer_id: nil).order(created_at: :desc).limit(15).to_a
      @no_email = ServiceRequest.where(customer_id: nil).where(email: [nil, ""]).count
      @setting = PortalSetting.current
      @mail_ready = ENV["SMTP_ADDRESS"].present?
    end
  end
end
