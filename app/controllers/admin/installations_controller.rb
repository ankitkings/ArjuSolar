module Admin
  # Admin controls what the website shows for a finished installation
  class InstallationsController < BaseController
    def update
      inst = Installation.find(params[:id])
      if inst.update(params.require(:installation).permit(:public_location, :show_on_website))
        redirect_to admin_service_request_path(inst.service_request), notice: "Website settings saved"
      else
        redirect_to admin_service_request_path(inst.service_request), alert: inst.errors.full_messages.to_sentence
      end
    end
  end
end
