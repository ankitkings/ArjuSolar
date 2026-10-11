# Catalog of the systems we install (capacity, panels, panel brand, inverter, price, picture).
# The installation team picks one when finishing an installation; the admin's picture
# is shown on the public Systems page.
class SolarPackage < ApplicationRecord
  include ImageAttachment

  has_one_attached :image
  has_many :installations, dependent: :nullify
  has_many :quotes, dependent: :nullify
  has_many :package_items, -> { order(:position, :id) }, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :capacity_kw, numericality: { greater_than: 0, less_than: 1000 }
  validates :panel_count, numericality: { only_integer: true, greater_than: 0 }
  validates :panel_brand, :inverter_model, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates_image :image

  scope :available, -> { where(active: true).order(:capacity_kw, :name) }

  # Price, number of panels, panel brand and inverter worked out from a list of [catalog_item, quantity]
  def self.attributes_from_parts(rows)
    panels    = rows.select { |item, _| item.category == "panel" }
    inverters = rows.select { |item, _| item.category == "inverter" }
    attrs = { price: rows.sum { |item, qty| item.unit_price * qty.to_d } }
    if panels.any?
      attrs[:panel_count] = panels.sum { |_, qty| qty.to_d.round }
      attrs[:panel_brand] = panels.map { |item, _| item.name }.uniq.join(" + ")
    end
    attrs[:inverter_model] = inverters.map { |item, _| item.name }.uniq.join(" + ") if inverters.any?
    attrs
  end

  # Replaces the system's parts with [[catalog_item, quantity], ...]
  def replace_parts!(rows)
    transaction do
      package_items.destroy_all
      rows.each_with_index { |(item, qty), i| package_items.create!(catalog_item: item, quantity: qty, position: i) }
    end
  end

  # Called when a part's price changes: the system's price follows
  def sync_from_parts!
    rows = package_items.includes(:catalog_item).map { |pi| [pi.catalog_item, pi.quantity] }
    update!(self.class.attributes_from_parts(rows)) if rows.any?
  end

  def parts_total = package_items.includes(:catalog_item).sum(&:line_total)

  # Central subsidy for a home system of this size, and what the client effectively pays
  def subsidy_amount
    return 0 unless subsidy_eligible
    [SubsidyScheme.current.amount_for(capacity_kw), price.to_d].min
  end

  def effective_cost = price.to_d - subsidy_amount

  def label = "#{name} — #{format('%g', capacity_kw.to_f)} kW — #{Rupees.display(price)}"

  def details
    "Capacity #{format('%g', capacity_kw.to_f)} kW · #{panel_count} panels · #{panel_brand} · Inverter #{inverter_model} · Price #{Rupees.display(price)}"
  end
end
