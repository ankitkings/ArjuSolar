module Portal
  # The client asks for an installation and follows its progress
  class RequestsController < BaseController
    def new
      @service_request = ServiceRequest.new
      @packages = SolarPackage.available.order(:capacity_kw)
    end

    def create
      if current_customer.service_requests.where("created_at > ?", 1.day.ago).count >= 3
<<<<<<< Updated upstream
        return redirect_to(portal_root_path, alert: "You have already sent three requests today. Please wait for our call, or phone us on #{SiteSetting.current.primary_phone || 'our office'}.")
=======
        return redirect_to(portal_root_path, alert: "You have already sent three requests today. Please wait for our call, or phone us on +91 7049465926.")
>>>>>>> Stashed changes
      end

      permitted = params.require(:service_request).permit(:address, :message)
      package = SolarPackage.available.find_by(id: params[:solar_package_id])
      @service_request = ServiceRequest.new(address: permitted[:address], name: current_customer.name, phone: current_customer.phone,
                                            email: current_customer.email, customer: current_customer, ip_address: request.remote_ip)
      @service_request.message = [("Interested in: #{package.label}" if package), permitted[:message].to_s.strip.presence].compact.join("\n")

      if @service_request.save
        @service_request.updates.create!(status: "pending", progress: 0, note: "Request received from the client portal (#{current_customer.email}).")
        redirect_to portal_request_path(@service_request), notice: "Thank you! Your request was sent. We will call you soon."
      else
        @packages = SolarPackage.available.order(:capacity_kw)
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @service_request = current_customer.service_requests.includes(:installation, :payment, :quotes).find(params[:id])
      @reached = {}                                   # the day each stage was reached (no internal notes are shown)
      @service_request.updates.to_a.reverse_each { |update| @reached[update.status] ||= update.created_at }
      @quote = @service_request.quotes.reject { |quote| quote.status == "superseded" }.last
      @installation = @service_request.installation
      @issues = @service_request.maintenance_visits.where(kind: "client_issue").reorder(created_at: :desc).includes(:team_member).to_a
    end
  end
end
