class MaintenanceVisit < ApplicationRecord
  STATUSES = %w[scheduled assigned done].freeze

  # Default checks after an installation. Edit this list to change the schedule.
  SCHEDULE = [
    ["First check (15 days)", 15.days],
    ["Second check (2 months)", 2.months]
  ].freeze

  belongs_to :service_request
  belongs_to :installation
  belongs_to :team_member, optional: true

  validates :title, presence: true
  validates :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }

  # Assigns every scheduled visit whose date has arrived to the least busy
  # Daily Servicing member. Safe to call any number of times.
  def self.assign_due!
    count = 0
    where(status: "scheduled").where("due_on <= ?", Date.current).find_each do |visit|
      member = TeamMember.least_busy("daily_servicing")
      next unless member
      visit.assign_to!(member)
      count += 1
    end
    count
  end

  def assign_to!(member)
    transaction do
      update!(team_member: member, status: "assigned", assigned_at: Time.current)
      req = service_request
      req.updates.create!(status: req.status, progress: req.progress,
                          note: "Maintenance \"#{title}\" (due #{due_on.strftime('%d %b %Y')}) auto-assigned to #{member.name}")
    end
  end

  def finish!(report = nil)
    transaction do
      update!(status: "done", completed_at: Time.current, report: report.to_s.strip.presence)
      req = service_request
      req.updates.create!(status: req.status, progress: req.progress, team_member: team_member,
                          note: "Maintenance \"#{title}\" done#{": #{report.to_s.strip}" if report.to_s.strip.present?}")
    end
  end

  def overdue? = status != "done" && due_on < Date.current
end
