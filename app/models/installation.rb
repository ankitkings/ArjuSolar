# The installed solar system (saved when the installation team completes a request)
class Installation < ApplicationRecord
  belongs_to :service_request
  has_many :maintenance_visits, dependent: :destroy

  validates :installed_on, presence: true
  validates :capacity_kw, presence: true, numericality: { greater_than: 0, less_than: 1000 }
  validates :panel_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :service_request_id, uniqueness: true
  validate :installed_on_not_in_future

  def summary
    parts = ["#{capacity_kw.to_f} kW"]
    parts << "#{panel_count} panels" if panel_count
    parts << panel_brand if panel_brand.present?
    parts.join(", ")
  end

  # Creates the default maintenance dates (see MaintenanceVisit::SCHEDULE)
  def schedule_maintenance!
    MaintenanceVisit::SCHEDULE.map do |title, interval|
      maintenance_visits.create!(service_request: service_request, title: title, due_on: installed_on + interval)
    end
  end

  private

  def installed_on_not_in_future
    errors.add(:installed_on, "cannot be in the future") if installed_on.present? && installed_on > Date.current
  end
end
