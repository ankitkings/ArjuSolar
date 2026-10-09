# Catalog of the systems we install (capacity, panels, panel brand, inverter, price, picture).
# The installation team picks one when finishing an installation; the admin's picture
# is shown on the public Systems page.
class SolarPackage < ApplicationRecord
  include ImageAttachment

  has_one_attached :image
  has_many :installations, dependent: :nullify
  has_many :quotes, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :capacity_kw, numericality: { greater_than: 0, less_than: 1000 }
  validates :panel_count, numericality: { only_integer: true, greater_than: 0 }
  validates :panel_brand, :inverter_model, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates_image :image

  scope :available, -> { where(active: true).order(:capacity_kw, :name) }

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
