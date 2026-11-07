# Rules used for attendance and salary (Admin > Payroll)
class AttendanceSetting < ApplicationRecord
  validates :full_day_hours, numericality: { greater_than: 0, less_than_or_equal_to: 16 }

  after_save :recheck_attendance, if: :saved_change_to_full_day_hours?

  def self.current = first || create!

  private

  # days the employees checked in and out themselves follow the new rule (days corrected by the admin stay as they are)
  def recheck_attendance
    Attendance.where(marked_by: "self").where.not(check_in_at: nil).where.not(check_out_at: nil).find_each do |record|
      status = record.status_for_hours
      record.update_columns(status: status) unless record.status == status
    end
  end
end
