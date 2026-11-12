# Any visitor of the website can ask for a solar installation: no account and no login needed.
# It becomes a normal request, assigned and followed up exactly like the ones from the Contact page.
class InstallationRequestsController < ApplicationController
  PROPERTY_TYPES = RequestDetails::PROPERTY_TYPES
  BILLS = RequestDetails::BILLS
  ROOFS = RequestDetails::ROOFS
  PER_HOUR = 5   # requests from one internet address in an hour

  def new
    @service_request = ServiceRequest.new
    @packages = SolarPackage.available.order(:capacity_kw)
    @chosen_package = params[:package].presence
  end

  def create
    return render(:thanks) if params[:website].present?   # a hidden field only bots fill: pretend it worked

    attrs = params.require(:service_request).permit(:name, :phone, :email, :address)
    @service_request = ServiceRequest.new(attrs.merge(ip_address: request.remote_ip, message: RequestDetails.compose(params)))
    @packages = SolarPackage.available.order(:capacity_kw)
    @chosen_package = params[:package_id].presence

    if ServiceRequest.where(ip_address: request.remote_ip).where("created_at > ?", 1.hour.ago).count >= PER_HOUR
      @service_request.errors.add(:base, "Too many requests were sent from this connection. Please call us instead, or try again in an hour.")
      return render(:new, status: :too_many_requests)
    end

    if @service_request.save
      @service_request.updates.create!(status: "pending", progress: 0, note: "Installation request received from the website request form.")
      render :thanks
    else
      render :new, status: :unprocessable_entity
    end
  end
end
