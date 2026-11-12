module Staff
  # A site visitor meets a client in the field and creates the request there and then.
  # Started "on site", the request goes straight to the Site visit stage, owned by the person who created it,
  # so the quotation can be made right away. Otherwise it starts normally and the office calls the client first.
  class RequestsController < BaseController
    before_action :only_site_visitors

    def new
      @service_request = ServiceRequest.new
      @packages = SolarPackage.available.order(:capacity_kw)
    end

    def create
      attrs = params.require(:service_request).permit(:name, :phone, :email, :address)
      on_site = params[:start_on_site] == "1"
      lines = ["Created by #{current_staff.name} (Site Visitor)#{' at the client\'s site' if on_site}."]
      @service_request = ServiceRequest.new(attrs.merge(ip_address: request.remote_ip, message: RequestDetails.compose(params, extra_lines: lines)))
      @packages = SolarPackage.available.order(:capacity_kw)

      if (twin = duplicate_of(@service_request)) && params[:force] != "1"
        @duplicate = twin
        @service_request.errors.add(:base, "There is already an open request for this phone number: ##{twin.id} (#{twin.name}). If this is a new, different request, tick “Create it anyway”.")
        return render(:new, status: :unprocessable_entity)
      end

      if on_site
        @service_request.status = "site_visit"             # the client has been met: straight to the site visit
        @service_request.team_member = current_staff       # and it is mine, so no automatic assignment
      end

      if @service_request.save
        note = on_site ? "Request created on site by #{current_staff.name} (Site Visitor)." : "Request created by #{current_staff.name} (Site Visitor). The office will contact the client."
        @service_request.updates.create!(status: @service_request.status, progress: @service_request.progress, team_member: current_staff, note: note)
        if on_site
          redirect_to staff_task_path(@service_request), notice: "Request ##{@service_request.id} created. It is at the Site visit stage and assigned to you: you can make the quotation now."
        else
          redirect_to staff_root_path, notice: "Request ##{@service_request.id} created. The office will contact #{@service_request.name}."
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def only_site_visitors
      redirect_to staff_root_path, alert: "Only site visitors can create requests here." unless current_staff.department == "site_visitor"
    end

    # an open request for the same phone number from the last 3 days
    def duplicate_of(candidate)
      key = Customer.phone_key_for(candidate.phone)
      return nil if key.length < 10
      ServiceRequest.where(phone_key: key).where.not(status: %w[completed cancelled]).where("created_at > ?", 3.days.ago).order(:created_at).last
    end
  end
end
