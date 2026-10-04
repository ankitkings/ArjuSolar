module Admin
  class MaintenanceVisitsController < BaseController
    def index
      MaintenanceVisit.assign_due!
      @filter = params[:filter].presence_in(%w[upcoming assigned done all]) || "upcoming"
      scope = MaintenanceVisit.includes(:service_request, :team_member).order(:due_on)
      @visits = case @filter
                when "upcoming" then scope.where(status: "scheduled")
                when "assigned" then scope.where(status: "assigned")
                when "done"     then scope.where(status: "done")
                else scope
                end
      @counts = MaintenanceVisit.group(:status).count
      @installations = Installation.includes(:service_request).order(installed_on: :desc)
    end

    # Add an extra maintenance date for an installed system
    def create
      inst = Installation.find(params[:installation_id])
      visit = inst.maintenance_visits.new(service_request: inst.service_request,
                                          title: params[:title].presence || "Maintenance check",
                                          due_on: params[:due_on])
      if visit.save
        redirect_to admin_maintenance_visits_path, notice: "Maintenance date added"
      else
        redirect_to admin_maintenance_visits_path, alert: visit.errors.full_messages.to_sentence
      end
    end

    # Reschedule
    def update
      visit = MaintenanceVisit.find(params[:id])
      return redirect_to(admin_maintenance_visits_path, alert: "A finished visit cannot be rescheduled.") if visit.status == "done"

      visit.due_on = params[:due_on]
      if visit.due_on.present? && visit.due_on > Date.current && visit.status == "assigned"
        visit.assign_attributes(status: "scheduled", team_member: nil, assigned_at: nil)   # will be assigned again on the new date
      end
      if visit.save
        redirect_to admin_maintenance_visits_path(filter: "all"), notice: "Date updated"
      else
        redirect_to admin_maintenance_visits_path, alert: visit.errors.full_messages.to_sentence
      end
    end

    def destroy
      visit = MaintenanceVisit.find(params[:id])
      if visit.status == "done"
        redirect_to admin_maintenance_visits_path, alert: "A finished visit cannot be deleted."
      else
        visit.destroy
        redirect_to admin_maintenance_visits_path, notice: "Maintenance visit deleted"
      end
    end
  end
end
