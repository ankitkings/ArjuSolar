module Admin
  # Admin > Attendance: who is in today (or any day), with corrections
  class AttendanceController < BaseController
    def index
      @date = parse_date(params[:date]) || Date.current
      @members = TeamMember.where(active: true).order(:department, :name).to_a
      @records = Attendance.where(date: @date).index_by(&:team_member_id)
      @leaves = LeaveRequest.approved.where("from_date <= ? AND to_date >= ?", @date, @date).index_by(&:team_member_id)
      @holiday = Holiday.on(@date)
      @off_day = (AttendanceSetting.current.sunday_off && @date.sunday?) || @holiday.present?
    end

    # Mark or correct one employee's day
    def mark
      member = TeamMember.find(params[:member_id])
      date = parse_date(params[:date]) || Date.current
      record = Attendance.find_or_initialize_by(team_member_id: member.id, date: date)

      if params[:status] == "clear"
        record.destroy if record.persisted?
        return redirect_to(admin_attendance_path(date: date.iso8601), notice: "#{member.name}: attendance cleared.")
      end

      record.assign_attributes(status: params[:status], note: params[:note].to_s.strip.presence, marked_by: "admin")
      if record.save
        redirect_to admin_attendance_path(date: date.iso8601), notice: "#{member.name}: #{record.status_label}."
      else
        redirect_to admin_attendance_path(date: date.iso8601), alert: record.errors.full_messages.to_sentence
      end
    end

    private

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
