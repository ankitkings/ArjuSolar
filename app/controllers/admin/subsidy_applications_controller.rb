module Admin
  # Admin > Subsidy: who has applied for the PM Surya Ghar subsidy, how far it is, who received it and who did not
  class SubsidyApplicationsController < BaseController
    def index
      @group = params[:group].presence_in(SubsidyApplication::GROUP_STATUSES.keys)
      scope = SubsidyApplication.includes(service_request: :installation).order(updated_at: :desc)
      scope = scope.in_group(@group) if @group
      if params[:q].present?
        q = "%#{SubsidyApplication.sanitize_sql_like(params[:q])}%"
        scope = scope.joins(:service_request)
                     .where("service_requests.name LIKE :q OR service_requests.phone LIKE :q OR subsidy_applications.portal_application_no LIKE :q", q: q)
      end
      @applications = scope.to_a

      @counts = SubsidyApplication::GROUP_STATUSES.keys.index_with { |g| SubsidyApplication.in_group(g).count }
      @received_total = SubsidyApplication.in_group("received").sum(:received_amount)
      @waiting_total  = SubsidyApplication.in_group("in_progress").sum(:expected_amount)

      # clients whose quote includes the subsidy but nobody has started an application for yet
      @not_started = ServiceRequest.where.not(status: "cancelled")
                                   .where(id: Quote.where(subsidy_applies: true, status: "accepted").select(:service_request_id))
                                   .where.not(id: SubsidyApplication.select(:service_request_id))
                                   .order(:created_at).to_a
    end

    def show
      @application = SubsidyApplication.includes(:service_request).find(params[:id])
    end

    def create
      request = ServiceRequest.find(params[:service_request_id])
      application = request.subsidy_application
      unless application
        application = SubsidyApplication.start_for!(request)
        request.updates.create!(status: request.status, progress: request.progress, admin_user: current_admin,
                                note: "PM Surya Ghar subsidy application started")
      end
      redirect_to admin_subsidy_application_path(application)
    end

    def update
      @application = SubsidyApplication.find(params[:id])
      old_status = @application.status
      @application.assign_attributes(application_params)
      if @application.save
        if @application.status != old_status
          req = @application.service_request
          req.updates.create!(status: req.status, progress: req.progress, admin_user: current_admin,
                              note: "PM Surya Ghar subsidy: #{@application.status_label}")
        end
        redirect_to admin_subsidy_application_path(@application), notice: "Saved"
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def application_params
      params.require(:subsidy_application).permit(
        :status, :consumer_number, :discom, :portal_application_no, :system_capacity_kw, :expected_amount,
        :received_amount, :applied_on, :feasibility_on, :net_meter_on, :commissioned_on, :bank_submitted_on, :received_on,
        :rejection_reason, :notes, :electricity_bill_received, :bank_account_confirmed, :cancelled_cheque_received,
        :roof_ownership_confirmed
      )
    end
  end
end
