# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      MaintenanceVisit.assign_due!
      @overdue = OverdueSteps.new
      @team_total = TeamMember.where(active: true).count
      @present_today = Attendance.where(date: Date.current, status: %w[present half_day]).count
      @unassigned = ServiceRequest.where(status: RequestWorkflow::ACTIVE_STATUSES, team_member_id: nil,
                                         assigned_to_admin: false).count
      @with_admin = ServiceRequest.where(assigned_to_admin: true).count
      # PM Surya Ghar applications that are not finished: the ones holding up a job come first
      @subsidy_open = SubsidyApplication.in_group('in_progress').includes(:service_request).to_a
                                        .sort_by { |a| [a.service_request.assigned_to_admin? ? 0 : 1, a.updated_at] }
      @subsidy_counts = @subsidy_open.group_by(&:status).transform_values(&:size)
      @maintenance_due = MaintenanceVisit.where(status: %w[scheduled assigned]).where('due_on <= ?',
                                                                                      Date.current + 7).count
      @payments_pending = Payment.where.not(status: 'received').count
      @outstanding = Payment.where.not(status: 'received').includes(:receipts).sum { |p| p.balance || 0 }
      @visits_total  = Visit.count
      @visits_today  = Visit.where(visited_at: Time.current.all_day).count
      @unique_visitors = Visit.distinct.count(:ip_address)
      @requests_total = ServiceRequest.count
      @by_status = ServiceRequest.group(:status).count
      @recent = ServiceRequest.includes(:team_member, :subsidy_application).order(created_at: :desc).limit(5)
      @new_requests = ServiceRequest.where(status: 'pending').includes(:team_member).order(:created_at).to_a # not addressed yet, oldest first
    end
  end
end
