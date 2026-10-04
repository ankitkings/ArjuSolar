module Admin
  class ServiceRequestsController < BaseController
    before_action :set_service_request, only: %i[show update complete]

    def index
      @requests = ServiceRequest.includes(:team_member).order(created_at: :desc)
      @requests = @requests.where(status: params[:status]) if ServiceRequest::STATUSES.include?(params[:status])
      @requests = @requests.where(team_member_id: nil, status: RequestWorkflow::ACTIVE_STATUSES) if params[:unassigned].present?
      if params[:q].present?
        q = "%#{ServiceRequest.sanitize_sql_like(params[:q])}%"
        @requests = @requests.where("name LIKE :q OR phone LIKE :q OR email LIKE :q", q: q)
      end
    end

    def show
      @installation = Installation.new(installed_on: Date.current)
    end

    # Admin override: change stage (auto-assigns the next department) and/or reassign by hand
    def update
      attrs = params.require(:service_request).permit(:status, :team_member_id)
      note = params[:note].to_s.strip.presence
      new_status = attrs[:status].presence

      if new_status == "completed" && @service_request.status != "completed"
        return redirect_to(admin_service_request_path(@service_request), alert: "To complete a request, fill in the installation details form.")
      end

      old_member_id = @service_request.team_member_id
      chosen_id = attrs[:team_member_id].presence&.to_i
      member_changed = attrs.key?(:team_member_id) && chosen_id != old_member_id

      ServiceRequest.transaction do
        if new_status && new_status != @service_request.status
          @service_request.advance!(to: new_status, admin: current_admin, note: note)
          note = nil
        end
        if member_changed
          @service_request.assign_to!(TeamMember.find_by(id: chosen_id), admin: current_admin, note: note)
          note = nil
        end
        if note
          @service_request.updates.create!(status: @service_request.status, progress: @service_request.progress,
                                           admin_user: current_admin, note: note)
        end
      end
      redirect_to admin_service_request_path(@service_request), notice: "Request updated"
    rescue ActiveRecord::RecordInvalid
      @installation = Installation.new(installed_on: Date.current)
      render :show, status: :unprocessable_entity
    end

    def complete
      unless @service_request.status == "installation"
        return redirect_to(admin_service_request_path(@service_request), alert: "Only requests in the Installation stage can be completed.")
      end

      @installation = Installation.new(installation_params)
      @installation.service_request = @service_request
      if @installation.valid?
        @service_request.complete_installation!(@installation, admin: current_admin)
        redirect_to admin_service_request_path(@service_request), notice: "Installation saved. Maintenance and payment tasks were created."
      else
        render :show, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_service_request_path(@service_request), alert: e.message
    end

    private

    def set_service_request
      @service_request = ServiceRequest.find(params[:id])
    end

    def installation_params
      params.require(:installation).permit(:installed_on, :capacity_kw, :panel_count, :panel_brand, :inverter_model, :site_address, :notes)
    end
  end
end
