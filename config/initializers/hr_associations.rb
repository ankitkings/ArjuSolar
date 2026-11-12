# Attendance and leave belong to a team member (kept here so TeamMember itself stays as it is)
Rails.application.config.to_prepare do
  TeamMember.class_eval do
    has_many :attendances, dependent: :destroy
    has_many :leave_requests, dependent: :destroy

    # New work goes to somebody who is present: nobody on approved leave (or marked absent today) is chosen.
    # Among the people who are present, the one with the fewest active tasks gets it.
    # If several have the same number of active tasks, the one who has completed the fewest tasks gets it.
    def self.least_busy(department)
      away = Availability.unavailable_ids
      members = where(department: department, active: true).order(:id).to_a.reject { |m| away.include?(m.id) }
      return nil if members.empty?
      counts = active_task_counts
      fewest = members.map { |m| counts[m.id].to_i }.min
      tied = members.select { |m| counts[m.id].to_i == fewest }
      return tied.first if tied.one?
      tied.min_by { |m| [CompletedWork.new(m).total, m.id] }
    end

    def on_leave_today? = Availability.unavailable_ids.include?(id)
  end
end
