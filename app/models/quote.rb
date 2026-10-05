# A price quotation made after the site visit, built from the system price list.
# System details and prices are copied onto the quote, so later price changes never alter it.
class Quote < ApplicationRecord
  STATUSES = %w[sent accepted declined superseded].freeze
  DEFAULT_VALIDITY_DAYS = 15

  belongs_to :service_request
  belongs_to :solar_package, optional: true
  belongs_to :team_member, optional: true

  before_validation :set_defaults
  before_validation :copy_from_package, on: :create
  before_validation :calculate_total

  validates :solar_package, presence: { message: "must be selected" }, on: :create
  validates :list_price, numericality: { greater_than: 0 }
  validates :discount, numericality: { greater_than_or_equal_to: 0 }
  validates :valid_until, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :discount_not_more_than_price
  validate :package_has_price, on: :create

  after_create :assign_number

  def expired? = status == "sent" && valid_until < Date.current

  def details
    "#{format('%g', capacity_kw.to_f)} kW · #{panel_count} panels · #{panel_brand} · Inverter #{inverter_model}"
  end

  private

  def set_defaults
    self.discount = 0 if discount.nil?
    self.valid_until ||= Date.current + DEFAULT_VALIDITY_DAYS
  end

  def copy_from_package
    return unless solar_package
    self.system_name    = solar_package.name
    self.capacity_kw    = solar_package.capacity_kw
    self.panel_count    = solar_package.panel_count
    self.panel_brand    = solar_package.panel_brand
    self.inverter_model = solar_package.inverter_model
    self.list_price     = solar_package.price
  end

  def calculate_total
    self.total = list_price - discount if list_price && discount
  end

  def discount_not_more_than_price
    errors.add(:discount, "cannot be more than the price") if list_price && discount && discount > list_price
  end

  def package_has_price
    errors.add(:solar_package, "has no price yet – set it in Admin → Systems") if solar_package && solar_package.price.nil?
  end

  def assign_number
    update_column(:number, format("QT-%d-%05d", created_at.year, id))
  end
end
