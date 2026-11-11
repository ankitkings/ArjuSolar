# Any visitor of the website can ask for a solar installation: no account and no login needed.
# It becomes a normal request, assigned and followed up exactly like the ones from the Contact page.
class InstallationRequestsController < ApplicationController
  PROPERTY_TYPES = ["Home / independent house", "Apartment / society", "Shop / office", "Factory / industry", "Farm / agriculture", "School / institution", "Other"].freeze
  BILLS = ["Below ₹1,500", "₹1,500 – ₹3,000", "₹3,000 – ₹6,000", "₹6,000 – ₹10,000", "Above ₹10,000", "Not sure"].freeze
  ROOFS = ["RCC flat roof", "Tin / metal shed", "Tile / sloped roof", "Open land / ground", "Not sure"].freeze
  PER_HOUR = 5   # requests from one internet address in an hour

  def new
    @service_request = ServiceRequest.new
    @packages = SolarPackage.available.order(:capacity_kw)
    @chosen_package = params[:package].presence
  end

  def create
    return render(:thanks) if params[:website].present?   # a hidden field only bots fill: pretend it worked

    attrs = params.require(:service_request).permit(:name, :phone, :email, :address)
    @service_request = ServiceRequest.new(attrs.merge(ip_address: request.remote_ip, message: composed_message))
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

  private

  # the details become the message the team reads on the request
  def composed_message
    lines = []
    lines << "Property: #{params[:property]}" if PROPERTY_TYPES.include?(params[:property])
    lines << "Monthly electricity bill: #{params[:bill]}" if BILLS.include?(params[:bill])
    lines << "Roof: #{params[:roof]}" if ROOFS.include?(params[:roof])
    package = SolarPackage.available.find_by(id: params[:package_id])
    lines << "Interested in: #{package.label}" if package
    visit = (Date.iso8601(params[:visit_on].to_s) rescue nil)
    lines << "Preferred site-visit date: #{visit.strftime('%d %b %Y')}" if visit && visit.between?(Date.current, Date.current + 60)
    notes = params[:notes].to_s.strip.first(1000)
    lines << "Notes: #{notes}" if notes.present?
    lines.join("\n")
  end
end
