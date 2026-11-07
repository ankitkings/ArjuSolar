# frozen_string_literal: true

module Staff
  # Staff > Leaves: apply for leave and see whether it was approved or cancelled
  class LeaveRequestsController < BaseController
    def index
      @leave = LeaveRequest.new(kind: 'paid', from_date: Date.current, to_date: Date.current)
      load_leaves
    end

    def create
      @leave = LeaveRequest.new(params.require(:leave_request).permit(:kind, :from_date, :to_date, :reason))
      @leave.team_member = current_staff
      if @leave.save
        redirect_to staff_leave_requests_path,
                    notice: "Your leave request for #{@leave.days} #{'day'.pluralize(@leave.days)} was sent to the admin."
      else
        load_leaves
        render :index, status: :unprocessable_entity
      end
    end

    # only a request that is still waiting can be withdrawn
    def cancel
      leave = LeaveRequest.where(team_member_id: current_staff.id, status: 'pending').find(params[:id])
      leave.cancel!(by: 'employee')
      redirect_to staff_leave_requests_path, notice: 'Your leave request was cancelled.'
    end

    private

    def load_leaves
      @leaves = LeaveRequest.where(team_member_id: current_staff.id).order(from_date: :desc).to_a
    end
  end
end
