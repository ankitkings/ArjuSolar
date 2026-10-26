# Who can take work on a given day
class Availability
  # ids of the team members who cannot take work on this date: on approved leave, or marked absent today
  def self.unavailable_ids(date = Date.current)
    ids = LeaveRequest.approved.where("from_date <= ? AND to_date >= ?", date, date).pluck(:team_member_id)
    ids += Attendance.where(date: date, status: "absent").pluck(:team_member_id) if date == Date.current
    ids.uniq
  end
end
