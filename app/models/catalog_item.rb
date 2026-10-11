# One part with its own price (the "parts price list"). Site visitors pick these to build a custom quote.
class CatalogItem < ApplicationRecord
  CATEGORIES = {
    "panel"      => "Solar panel",
    "inverter"   => "Inverter",
    "mounting"   => "Mounting structure",
    "cables"     => "Cables & connectors",
    "protection" => "Protection & earthing",
    "monitoring" => "Monitoring",
    "labour"     => "Installation & services",
    "other"      => "Other"
  }.freeze
  UNITS = %w[piece set kW meter job].freeze

  before_destroy { @package_ids_to_refresh = package_items.pluck(:solar_package_id) }
  has_many :quote_items, dependent: :nullify
  has_many :package_items, dependent: :destroy
  after_update :refresh_packages, if: :saved_change_to_unit_price?
  after_destroy :refresh_packages

  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :name, presence: true, uniqueness: { scope: :category }
  validates :unit, presence: true
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :capacity_kw, numericality: { greater_than: 0 }, allow_nil: true
  validates :capacity_kw, presence: { message: "is needed for panels and inverters (panel: watts ÷ 1000, inverter: its rating)" },
                          if: -> { %w[panel inverter].include?(category) }

  scope :available, -> { where(active: true).order(:name) }

  def category_label = CATEGORIES[category]

  private

  # systems built from this part get their price recalculated
  def refresh_packages
    ids = @package_ids_to_refresh || package_items.pluck(:solar_package_id)
    SolarPackage.where(id: ids).find_each(&:sync_from_parts!)
  end
end
