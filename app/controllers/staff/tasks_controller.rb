module Staff
  # A team member only ever sees work assigned to THEM:
  # request stages, maintenance visits (servicing) and payments (cashier).
  class TasksController < BaseController
    before_action :set_task, only: %i[show update advance complete]

    def index
      MaintenanceVisit.assign_due!
      scope = current_staff.service_requests.order(updated_at: :desc)
      @counts = {
        "open"      => scope.where(status: RequestWorkflow::ACTIVE_STATUSES).count,
        "completed" => scope.where(status: "completed").count,
        "all"       => scope.count
      }
      @filter = params[:filter].presence_in(@counts.keys) || "open"
      @tasks = case @filter
               when "open"      then scope.where(status: RequestWorkflow::ACTIVE_STATUSES)
               when "completed" then scope.where(status: "completed")
               else scope
               end
      @visits = current_staff.maintenance_visits.where(status: "assigned").includes(:service_request).order(:due_on).to_a
      @payments = current_staff.payments.where(status: %w[pending partial]).includes(:service_request, :receipts).order(:created_at).to_a
    end

    def show
      @installation = Installation.new(installed_on: Date.current, site_address: @task.address, solar_package_id: @task.accepted_quote&.solar_package_id)
    end

    # Add a note without changing the stage
    def update
      note = params[:note].to_s.strip
      return redirect_to(staff_task_path(@task), alert: "Write a note first.") if note.blank?

      @task.updates.create!(status: @task.status, progress: @task.progress, team_member: current_staff, note: note)
      redirect_to staff_task_path(@task), notice: "Note added"
    end

    # Stage buttons: moves the request on and hands it to the next department automatically
    def advance
      to = params[:to].to_s
      unless RequestWorkflow.allowed?(@task.status, to)
        return redirect_to(staff_task_path(@task), alert: "That step is not available for this request.")
      end

      @task.advance!(to: to, by: current_staff, note: params[:note].to_s.strip.presence)
      msg = "Request moved to #{@task.status_label}."
      if @task.team_member && @task.team_member != current_staff
        msg += " Handed over to #{@task.team_member.name} (#{@task.team_member.department_label})."
      elsif @task.team_member.nil? && RequestWorkflow::ACTIVE_STATUSES.include?(@task.status)
        msg += " No active member in the next department – the admin must assign it."
      end
      redirect_to staff_root_path, notice: msg
    end

    # Installation team: save the installed system data and complete the request
    def complete
      unless @task.status == "installation"
        return redirect_to(staff_task_path(@task), alert: "Only requests in the Installation stage can be completed.")
      end

      @installation = Installation.new(installation_params)
      @installation.service_request = @task
      if @installation.valid?
        @task.complete_installation!(@installation, by: current_staff)
        redirect_to staff_root_path, notice: "Installation saved and request completed. Maintenance and payment tasks were created."
      else
        render :show, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to staff_task_path(@task), alert: e.message
    end

    private

    def set_task
      @task = current_staff.service_requests.find(params[:id])
    end

    def installation_params
      params.require(:installation).permit(:installed_on, :solar_package_id, :site_address, :notes)
    end
  end
end
