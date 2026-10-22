# frozen_string_literal: true

# The rules for planning installations (Admin > Stock)
class InstallationSetting < ApplicationRecord
  validates :cutoff_hour, :work_end_hour, inclusion: { in: 0..23 }
  validates :jobs_per_installer_per_day, numericality: { only_integer: true, greater_than: 0 }

  def self.current = first || create!

  def cutoff_label = Time.zone.parse("#{cutoff_hour}:00").strftime('%-I %p')
  def work_end_label = Time.zone.parse("#{work_end_hour}:00").strftime('%-I %p')
end
