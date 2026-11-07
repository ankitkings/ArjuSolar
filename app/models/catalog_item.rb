# frozen_string_literal: true

# One part with its own price (the "parts price list"). Site visitors pick these to build a custom quote.
class CatalogItem < ApplicationRecord
  CATEGORIES = {
    'panel' => 'Solar panel',
    'inverter' => 'Inverter',
    'battery' => 'Battery',
    'mounting' => 'Mounting structure',
    'cables' => 'Cables & connectors',
    'protection' => 'Protection & earthing',
    'monitoring' => 'Monitoring',
    'labour' => 'Installation & services',
    'other' => 'Other'
  }.freeze
  UNITS = %w[piece set kW meter job].freeze

  before_destroy { @package_ids_to_refresh = package_items.pluck(:solar_package_id) }
  has_many :quote_items, dependent: :nullify
  has_many :package_items, dependent: :destroy
  has_many :stock_movements, dependent: :destroy
  has_many :stock_reservations, dependent: :destroy
  has_many :stock_orders, dependent: :destroy
  after_update :refresh_packages, if: :saved_change_to_unit_price?
  after_destroy :refresh_packages

  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :name, presence: true, uniqueness: { scope: :category }
  validates :unit, presence: true
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_price, :margin, numericality: { greater_than_or_equal_to: 0 }
  before_validation :sync_prices
  validates :capacity_kw, numericality: { greater_than: 0 }, allow_nil: true
  validates :capacity_kw, presence: { message: 'is needed for panels and inverters (panel: watts ÷ 1000, inverter: its rating)' },
                          if: -> { %w[panel inverter].include?(category) }

  scope :available, -> { where(active: true).order(:name) }

  def category_label = CATEGORIES[category]

  # our profit as a share of the selling price
  def margin_percent = unit_price.to_f.positive? ? (margin.to_f / unit_price * 100).round(1) : 0

  # Services (installation, paperwork, transport) are not kept in stock
  scope :stocked, -> { where.not(category: 'labour') }
  def tracks_stock? = category != 'labour'

  def reserved_quantity(except: nil)
    scope = stock_reservations
    scope = scope.where.not(service_request_id: except.id) if except
    scope.sum(:quantity)
  end

  # in stock and not set aside for another job
  def available_quantity(except: nil) = stock_quantity - reserved_quantity(except: except)

  # quantity: + when stock comes in, - when it is used. Every change is kept in the history.
  def add_stock!(quantity, kind:, note: nil, request: nil)
    transaction do
      self.class.where(id: id).update_all(['stock_quantity = stock_quantity + ?', quantity])
      stock_movements.create!(quantity: quantity, kind: kind, note: note, service_request: request)
      reload
    end
  end

  private

  # selling price (unit_price, what the client pays) = actual price (cost_price) + margin
  def sync_prices
    if new_record?
      if cost_price.to_d.zero? && margin.to_d.zero? # created from a selling price only: no margin until the actual price is entered
        self.cost_price = unit_price.to_d
        self.margin = 0
      else
        self.unit_price = cost_price + margin
      end
    elsif cost_price_changed? || margin_changed?
      self.unit_price = cost_price + margin
    elsif unit_price_changed? # selling price edited directly (Parts page): the margin follows
      self.margin = [unit_price - cost_price, 0].max
      self.cost_price = unit_price if unit_price < cost_price
    end
  end

  # systems built from this part get their price recalculated
  def refresh_packages
    ids = @package_ids_to_refresh || package_items.pluck(:solar_package_id)
    SolarPackage.where(id: ids).find_each(&:sync_from_parts!)
  end
end
