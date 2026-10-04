module Admin
  class DashboardController < BaseController
    def index
      MaintenanceVisit.assign_due!
      @unassigned = ServiceRequest.where(status: RequestWorkflow::ACTIVE_STATUSES, team_member_id: nil).count
      @maintenance_due = MaintenanceVisit.where(status: %w[scheduled assigned]).where("due_on <= ?", Date.current + 7).count
      @payments_pending = Payment.where(status: "pending").count
      @visits_total  = Visit.count
      @visits_today  = Visit.where(visited_at: Time.current.all_day).count
      @unique_visitors = Visit.distinct.count(:ip_address)
      @requests_total = ServiceRequest.count
      @by_status = ServiceRequest.group(:status).count
      @recent = ServiceRequest.order(created_at: :desc).limit(5)
    end
  end
end
