class ServiceRequestsController < ApplicationController
  def create
    # Honeypot: bots fill the hidden "website" field
    return redirect_to(contact_path, notice: "Thank you! We will contact you soon.") if params[:website].present?

    @service_request = ServiceRequest.new(params.require(:service_request).permit(:name, :phone, :email, :message))
    @service_request.ip_address = request.remote_ip
    if @service_request.save
      owner = @service_request.team_member
      note = "Request received from website. " +
             (owner ? "Auto-assigned to #{owner.name} (#{owner.department_label})." : "No contact person available – please assign manually.")
      @service_request.updates.create!(status: "pending", progress: 0, note: note)
      redirect_to contact_path, notice: "Thank you! We will contact you soon."
    else
      render "pages/contact", status: :unprocessable_entity
    end
  end
end
