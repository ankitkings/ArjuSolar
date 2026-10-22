# frozen_string_literal: true

module Staff
  # Staff > Attendance: check in / out and see my month
  class AttendanceController < BaseController
    def show
      @month = parse_month(params[:month])
      payroll = Payroll.new(@month)
      @summary = payroll.summary(current_staff)
      @days = payroll.days(current_staff)
      @today = Attendance.find_by(team_member_id: current_staff.id, date: Date.current)
      @on_leave = leave_today
      @off_day = AttendanceSetting.current.sunday_off && Date.current.sunday?
    end

    def check_in
      return redirect_to(staff_attendance_path, alert: 'You are on approved leave today.') if leave_today

      record = Attendance.check_in!(current_staff)
      redirect_to staff_attendance_path,
                  notice: "Checked in at #{record.check_in_at.strftime('%I:%M %p')}. Have a good day!"
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to staff_attendance_path, alert: e.message
    end

    def check_out
      record = Attendance.find_by(team_member_id: current_staff.id, date: Date.current)
      return redirect_to(staff_attendance_path, alert: 'Check in first.') unless record

      record.check_out!
      redirect_to staff_attendance_path,
                  notice: "Checked out. You worked #{record.hours} hours today (#{record.status_label.downcase})."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to staff_attendance_path, alert: e.message
    end

    private

    def leave_today
      LeaveRequest.approved.where(team_member_id: current_staff.id).where('from_date <= ? AND to_date >= ?',
                                                                          Date.current, Date.current).first
    end

    def parse_month(value)
      Date.strptime(value.to_s, '%Y-%m')
    rescue ArgumentError
      Date.current.beginning_of_month
    end
  end
end
