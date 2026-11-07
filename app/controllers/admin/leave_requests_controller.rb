# frozen_string_literal: true

module Admin
  # Admin > Leaves: approve or cancel what the team asks for
  class LeaveRequestsController < BaseController
    def index
      @status = params[:status].presence_in(LeaveRequest::STATUSES)
      scope = LeaveRequest.includes(:team_member).order(
        Arel.sql("CASE leave_requests.status WHEN 'pending' THEN 0 ELSE 1 END"), from_date: :desc
      )
      scope = scope.where(status: @status) if @status
      @leaves = scope.to_a
      @counts = LeaveRequest.group(:status).count
    end

    def approve
      leave = LeaveRequest.find(params[:id])
      leave.approve!(kind: params[:kind])
      redirect_to admin_leave_requests_path(status: params[:back].presence),
                  notice: "Leave of #{leave.team_member.name} approved (#{leave.kind_label}, #{pluralize_days(leave)})."
    end

    def cancel
      leave = LeaveRequest.find(params[:id])
      leave.cancel!(by: 'admin', note: params[:admin_note])
      redirect_to admin_leave_requests_path(status: params[:back].presence),
                  notice: "Leave of #{leave.team_member.name} cancelled."
    end

    private

    def pluralize_days(leave) = "#{leave.days} #{'day'.pluralize(leave.days)}"
  end
end
