class QuoteItem < ApplicationRecord
  belongs_to :quote, inverse_of: :quote_items
  belongs_to :catalog_item, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  # Takes name / unit / price from the price list (never from the browser) and works out the line total
  def prepare
    if catalog_item
      self.category    = catalog_item.category
      self.description = catalog_item.name
      self.unit        = catalog_item.unit
      self.unit_price  = catalog_item.unit_price
      self.capacity_kw = catalog_item.capacity_kw
    end
    self.line_total = (quantity || 0) * (unit_price || 0)
  end
end
