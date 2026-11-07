# frozen_string_literal: true

module Admin
  # Admin > Attendance: who is in today (or any day), with corrections
  class AttendanceController < BaseController
    def index
      @date = parse_date(params[:date]) || Date.current
      @members = TeamMember.where(active: true).order(:department, :name).to_a
      @records = Attendance.where(date: @date).index_by(&:team_member_id)
      @leaves = LeaveRequest.approved.where('from_date <= ? AND to_date >= ?', @date, @date).index_by(&:team_member_id)
      @off_day = AttendanceSetting.current.sunday_off && @date.sunday?
    end

    # Mark or correct one employee's day
    def mark
      member = TeamMember.find(params[:member_id])
      date = parse_date(params[:date]) || Date.current
      record = Attendance.find_or_initialize_by(team_member_id: member.id, date: date)

      if params[:status] == 'clear'
        record.destroy if record.persisted?
        return redirect_to(admin_attendance_path(date: date.iso8601), notice: "#{member.name}: attendance cleared.")
      end

      record.assign_attributes(status: params[:status], note: params[:note].to_s.strip.presence, marked_by: 'admin')
      if record.save
        redirect_to admin_attendance_path(date: date.iso8601), notice: "#{member.name}: #{record.status_label}."
      else
        redirect_to admin_attendance_path(date: date.iso8601), alert: record.errors.full_messages.to_sentence
      end
    end

    def show
      @current_team_member = TeamMember.find(params[:id])
      @month = parse_month(params[:month])
      payroll = Payroll.new(@month)
      @summary = payroll.summary(@current_team_member)
      @days = payroll.days(@current_team_member)
      @today = Attendance.find_by(team_member_id: @current_team_member.id, date: Date.current)
      @on_leave = leave_today
      @off_day = AttendanceSetting.current.sunday_off && Date.current.sunday?
    end

    private

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def leave_today
      LeaveRequest.approved.where(team_member_id: @current_team_member.id).where('from_date <= ? AND to_date >= ?',
                                                                                 Date.current, Date.current).first
    end

    def parse_month(value)
      Date.strptime(value.to_s, '%Y-%m')
    rescue ArgumentError
      Date.current.beginning_of_month
    end
  end
end
