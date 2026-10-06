# The installed solar system (saved when the installation team finishes the installation).
# Capacity / panels / brand / inverter / price are copied from the chosen SolarPackage,
# so later edits to the catalog never change past installations.
class Installation < ApplicationRecord
  include ImageAttachment

  MAX_PHOTOS = 6

  belongs_to :service_request
  belongs_to :solar_package, optional: true
  has_many :maintenance_visits, dependent: :destroy
  has_many_attached :photos   # taken by the installer on site; shown on the website's Projects page

  attr_accessor :skip_photo_validation   # only used for demo seed data

  before_validation :copy_from_package

  validates :solar_package, presence: { message: "must be selected" }, on: :create
  validates :site_address, presence: true, on: :create
  validates :photos, presence: { message: "are required – take pictures of the finished site" }, on: :create, unless: :skip_photo_validation
  validates :installed_on, presence: true
  validates :capacity_kw, presence: true, numericality: { greater_than: 0, less_than: 1000 }
  validates :panel_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :service_request_id, uniqueness: true
  validate :installed_on_not_in_future
  validate :not_too_many_photos
  validates_image :photos

  # Completed projects with photos that the admin has not hidden (public Projects page)
  scope :on_website, -> {
    where(show_on_website: true)
      .where(service_request_id: ServiceRequest.where(status: "completed").select(:id))
      .where(id: ActiveStorage::Attachment.where(record_type: "Installation", name: "photos").select(:record_id))
  }

  # "Flat 12, Shree Apts, Vijay Nagar, Indore 452010" -> "Vijay Nagar, Indore"
  # (drops the parts with numbers, so no house number or PIN code is published)
  def self.guess_location(address)
    address.to_s.split(",").map(&:strip).reject { |part| part.empty? || part.match?(/\d/) }.last(2).join(", ")
  end

  def summary
    parts = ["#{format('%g', capacity_kw.to_f)} kW"]
    parts << "#{panel_count} panels" if panel_count
    parts << panel_brand if panel_brand.present?
    parts.join(", ")
  end

  # Creates the default maintenance dates (see MaintenanceVisit::SCHEDULE), counted from `from`
  def schedule_maintenance!(from = nil)
    from ||= installed_on
    MaintenanceVisit::SCHEDULE.map do |title, interval|
      maintenance_visits.create!(service_request: service_request, title: title, due_on: from + interval)
    end
  end

  private

  def copy_from_package
    return unless solar_package && (new_record? || solar_package_id_changed?)
    self.capacity_kw    = solar_package.capacity_kw
    self.panel_count    = solar_package.panel_count
    self.panel_brand    = solar_package.panel_brand
    self.inverter_model = solar_package.inverter_model
    self.package_price  = solar_package.price
  end

  def installed_on_not_in_future
    errors.add(:installed_on, "cannot be in the future") if installed_on.present? && installed_on > Date.current
  end

  def not_too_many_photos
    errors.add(:photos, "– please add at most #{MAX_PHOTOS} photos") if photos.attachments.size > MAX_PHOTOS
  end
end
