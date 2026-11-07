# One employee, one day. Staff check in / out; the admin can correct any day.
class Attendance < ApplicationRecord
  STATUSES = %w[present half_day absent].freeze
  LABELS = { "present" => "Present", "half_day" => "Half day", "absent" => "Absent" }.freeze
  DAYS = { "present" => 1.0, "half_day" => 0.5, "absent" => 0.0 }.freeze

  belongs_to :team_member

  validates :date, presence: true, uniqueness: { scope: :team_member_id }
  validates :status, inclusion: { in: STATUSES }
  validate :not_in_the_future
  validate :check_out_after_check_in

  def status_label = LABELS[status]
  def counted_days = DAYS[status]
  # a full day = at least the "full day" hours between check-in and check-out; less than that is a half day
  def status_for_hours
    hours && hours < AttendanceSetting.current.full_day_hours ? "half_day" : "present"
  end

  def hours = (check_in_at && check_out_at) ? ((check_out_at - check_in_at) / 3600.0).round(2) : nil

  # The employee starts the day
  def self.check_in!(member, now: Time.current)
    record = find_or_initialize_by(team_member_id: member.id, date: now.to_date)
    raise ArgumentError, "You have already checked in today." if record.check_in_at
    record.assign_attributes(status: "present", check_in_at: now, marked_by: "self")
    record.save!
    # work that was waiting because nobody in this department was present goes to them now
    statuses = RequestWorkflow::DEPARTMENT.select { |_status, department| department == member.department }.keys
    ServiceRequest.where(status: statuses, team_member_id: nil, assigned_to_admin: false).find_each(&:reassign_for_stage!) if statuses.any?
    record
  end

  # The employee ends the day; leaving before the half-day limit counts as half a day
  def check_out!(now: Time.current)
    raise ArgumentError, "Check in first." unless check_in_at
    raise ArgumentError, "You have already checked out today." if check_out_at
    self.check_out_at = now
    self.status = status_for_hours
    save!
  end

  private

  def not_in_the_future
    errors.add(:date, "cannot be in the future") if date && date > Date.current
  end

  def check_out_after_check_in
    errors.add(:check_out_at, "must be after the check-in") if check_in_at && check_out_at && check_out_at <= check_in_at
  end
end
