module Staff
  class MaintenanceVisitsController < BaseController
    before_action :set_visit

    def show; end

    def update
      unless @visit.status == "assigned"
        return redirect_to(staff_root_path, alert: "This visit is not open.")
      end
      @visit.finish!(params[:report])
      redirect_to staff_root_path, notice: "Maintenance visit marked as done"
    end

    private

    def set_visit
      @visit = current_staff.maintenance_visits.find(params[:id])
    end
  end
end
