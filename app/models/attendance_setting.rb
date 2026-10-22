# frozen_string_literal: true

# Rules used for attendance and salary (Admin > Payroll)
class AttendanceSetting < ApplicationRecord
  validates :half_day_hours, numericality: { greater_than: 0, less_than_or_equal_to: 12 }

  def self.current = first || create!
end
