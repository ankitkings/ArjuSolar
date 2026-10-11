# One part (and how many) in a ready-made system
class PackageItem < ApplicationRecord
  belongs_to :solar_package
  belongs_to :catalog_item

  validates :quantity, numericality: { greater_than: 0 }

  def line_total = catalog_item.unit_price * quantity
end
